local unitRndr = {}
local imageLoader = require("src.assets.image_loader")
local locationFacGeo = require("src.system.location_fac_geo")
local mapElements = require("src.render.map_elements")
local diceRndr = require("src.render.dice_rndr")
local sfx = require("src.audio.sfx")

local UNIT_IMAGE_EXTENSIONS = { "webp", "png", "jpg", "jpeg" }
local TARGET_BOX_FROM_BOTTOM = 2
local BOX_PADDING = 10
local UNIT_GAP = 8
local MIN_VISIBLE_UNIT_WIDTH = 18
local MAX_FITTED_UNITS = 20
local UNIT_SCROLL_STEP = 80
local DIE_BADGE_MIN_SIZE = 8
local DIE_BADGE_MAX_SIZE = 20
local DIE_BADGE_SIZE_FACTOR = 0.15
local DIE_BADGE_OUTLINE_WIDTH = 3
local PREVIEW_GAP = 16
local PREVIEW_IMAGE_SIZE = 168
local PREVIEW_LABEL_HEIGHT = 34
local PREVIEW_LABEL_PADDING = 14
local PREVIEW_LABEL_GAP = 6
local PREVIEW_DIE_GAP = 10

local unitIndex
local unitTesting
local diceIndex = {}
local unitImages = {}
local playerUnitScroll = 0
local hoveredUnitIndex

local function findUnitImagePath(unitId)
    for _, extension in ipairs(UNIT_IMAGE_EXTENSIONS) do
        local path = ("assets/images/units/%s.%s"):format(unitId, extension)

        if love.filesystem.getInfo(path, "file") then
            return path
        end
    end
end

local function loadUnitImage(unitId)
    if unitImages[unitId] ~= nil then
        return
    end

    local imagePath = findUnitImagePath(unitId)
    unitImages[unitId] = imagePath and imageLoader.newImage(imagePath) or false
end

local function drawUnitImage(unitId, x, y, size)
    local image = unitImages[unitId]

    if not image then
        return
    end

    local scale = math.min(size / image:getWidth(), size / image:getHeight())
    local width = image:getWidth() * scale
    local height = image:getHeight() * scale

    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(image, x + (size - width) / 2, y + (size - height) / 2, 0, scale, scale)
end

local function htmlColorToRgb(color)
    if type(color) ~= "string" then
        return 1, 1, 1
    end

    local hex = color:gsub("^#", "")
    if not hex:match("^%x%x%x%x%x%x$") then
        return 1, 1, 1
    end

    return tonumber(hex:sub(1, 2), 16) / 255,
        tonumber(hex:sub(3, 4), 16) / 255,
        tonumber(hex:sub(5, 6), 16) / 255
end

local function drawMissingUnit(unitId, x, y, size)
    love.graphics.setColor(0.12, 0.12, 0.12)
    love.graphics.rectangle("fill", x, y, size, size)

    love.graphics.setColor(1, 1, 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x, y, size, size)
    love.graphics.printf(unitId, x + 4, y + size / 2 - 10, size - 8, "center")
end

local function getUnitPrimaryDieId(unitId)
    local unit = unitIndex and unitIndex.byId[unitId]

    for _, dieEntry in ipairs(unit and unit.dice or {}) do
        for dieId in pairs(dieEntry) do
            return dieId
        end
    end
end

local function drawDieBadge(unitId, x, y, size)
    local dieId = getUnitPrimaryDieId(unitId)
    local die = dieId and diceIndex[dieId]

    if not die or not die.color then
        return
    end

    local badgeSize = math.max(DIE_BADGE_MIN_SIZE, math.min(DIE_BADGE_MAX_SIZE, size * DIE_BADGE_SIZE_FACTOR))
    local badgeX = x + size - badgeSize
    local badgeY = y
    local r, g, b = htmlColorToRgb(die.color)

    love.graphics.setColor(r, g, b)
    love.graphics.rectangle("fill", badgeX, badgeY, badgeSize, badgeSize)

    love.graphics.setColor(0, 0, 0)
    love.graphics.setLineWidth(DIE_BADGE_OUTLINE_WIDTH)
    love.graphics.rectangle("line", badgeX, badgeY, badgeSize, badgeSize)
end

local function drawUnit(unitId, x, y, size)
    if unitImages[unitId] then
        drawUnitImage(unitId, x, y, size)
    else
        drawMissingUnit(unitId, x, y, size)
    end

    drawDieBadge(unitId, x, y, size)
end

local function getUnitName(unitId)
    local unit = unitIndex and unitIndex.byId[unitId]

    return unit and unit.name or unitId
end

local function getDrawablePlayerUnits(facilityId)
    local drawableUnits = {}

    for _, entry in ipairs(unitTesting.playerunits or {}) do
        if entry.fac == facilityId and unitIndex.byId[entry.unit] then
            local unitCount = math.max(1, math.floor(entry.num or 1))

            for _ = 1, unitCount do
                table.insert(drawableUnits, entry.unit)
            end
        end
    end

    return drawableUnits
end

local function getUnitSpacing(unitCount, unitSize, availableWidth)
    local fittedCount = math.min(unitCount, MAX_FITTED_UNITS)

    if fittedCount <= 1 then
        return unitSize + UNIT_GAP
    end

    local relaxedWidth = fittedCount * unitSize + (fittedCount - 1) * UNIT_GAP

    if relaxedWidth <= availableWidth then
        return unitSize + UNIT_GAP
    end

    return math.max(MIN_VISIBLE_UNIT_WIDTH, (availableWidth - unitSize) / (fittedCount - 1))
end

local function getUnitRowLayout()
    local selectedFacility = locationFacGeo.getSelectedFacility()

    if not selectedFacility or not unitTesting then
        return nil
    end

    local boxX, boxY, boxWidth, boxHeight = mapElements.getRightBoxBounds(TARGET_BOX_FROM_BOTTOM)
    local unitSize = boxHeight - BOX_PADDING * 2
    local availableWidth = boxWidth - BOX_PADDING * 2
    local drawableUnits = getDrawablePlayerUnits(selectedFacility.id)
    local unitSpacing = getUnitSpacing(#drawableUnits, unitSize, availableWidth)
    local contentWidth = 0

    if #drawableUnits > 0 then
        contentWidth = unitSize + (#drawableUnits - 1) * unitSpacing
    end

    local maxScroll = math.max(0, contentWidth - availableWidth)
    playerUnitScroll = math.max(0, math.min(playerUnitScroll, maxScroll))

    return {
        boxX = boxX,
        boxY = boxY,
        boxWidth = boxWidth,
        boxHeight = boxHeight,
        unitSize = unitSize,
        availableWidth = availableWidth,
        drawableUnits = drawableUnits,
        unitSpacing = unitSpacing,
        maxScroll = maxScroll,
    }
end

local function getHoveredPlayerUnit(layout)
    if not layout or #layout.drawableUnits == 0 then
        return nil
    end

    local mouseX, mouseY = love.mouse.getPosition()

    if mouseX < layout.boxX
        or mouseX > layout.boxX + layout.boxWidth
        or mouseY < layout.boxY
        or mouseY > layout.boxY + layout.boxHeight then
        return nil
    end

    for index = 1, #layout.drawableUnits do
        local unitX = layout.boxX + BOX_PADDING - playerUnitScroll + (index - 1) * layout.unitSpacing
        local unitY = layout.boxY + BOX_PADDING

        if mouseX >= unitX
            and mouseX <= unitX + layout.unitSize
            and mouseY >= unitY
            and mouseY <= unitY + layout.unitSize then
            return layout.drawableUnits[index], index
        end
    end
end

local function drawUnitPreview(unitId, layout)
    local previewWidth = math.max(PREVIEW_IMAGE_SIZE, love.graphics.getFont():getWidth(getUnitName(unitId)) + PREVIEW_LABEL_PADDING * 2)
    local centerX = layout.boxX + layout.boxWidth / 2
    local imageX = centerX - PREVIEW_IMAGE_SIZE / 2
    local labelX = centerX - previewWidth / 2
    local imageY = layout.boxY - PREVIEW_GAP - PREVIEW_IMAGE_SIZE
    local labelY = imageY - PREVIEW_LABEL_GAP - PREVIEW_LABEL_HEIGHT
    local dieId = getUnitPrimaryDieId(unitId)
    local die = dieId and diceIndex[dieId]

    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle("fill", labelX, labelY, previewWidth, PREVIEW_LABEL_HEIGHT)

    love.graphics.setColor(1, 1, 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", labelX, labelY, previewWidth, PREVIEW_LABEL_HEIGHT)
    love.graphics.printf(getUnitName(unitId), labelX + PREVIEW_LABEL_PADDING, labelY + 5, previewWidth - PREVIEW_LABEL_PADDING * 2, "center")

    drawUnit(unitId, imageX, imageY, PREVIEW_IMAGE_SIZE)

    if die then
        local _, diePanelHeight = diceRndr.getPanelSize()
        diceRndr.drawDie(die, imageX + PREVIEW_IMAGE_SIZE + PREVIEW_DIE_GAP, imageY + (PREVIEW_IMAGE_SIZE - diePanelHeight) / 2)
    end
end

function unitRndr.load()
    unitIndex = require("data.units.index")
    unitTesting = require("data.unittesting")
    diceIndex = {}

    for _, die in ipairs(require("data.dice")) do
        diceIndex[die.id] = die
    end

    diceRndr.load()

    for _, entry in ipairs(unitTesting.playerunits or {}) do
        if unitIndex.byId[entry.unit] then
            loadUnitImage(entry.unit)
        end
    end
end

function unitRndr.isCursorOverPlayerUnits()
    local layout = getUnitRowLayout()

    if not layout then
        return false
    end

    local mouseX, mouseY = love.mouse.getPosition()

    return mouseX >= layout.boxX
        and mouseX <= layout.boxX + layout.boxWidth
        and mouseY >= layout.boxY
        and mouseY <= layout.boxY + layout.boxHeight
end

function unitRndr.scrollPlayerUnits(direction)
    local layout = getUnitRowLayout()

    if not layout or layout.maxScroll <= 0 then
        return
    end

    playerUnitScroll = math.max(0, math.min(playerUnitScroll + direction * UNIT_SCROLL_STEP, layout.maxScroll))
end

function unitRndr.drawPlayerUnits()
    local layout = getUnitRowLayout()

    if not layout or #layout.drawableUnits == 0 then
        return
    end

    local cursorX = layout.boxX + BOX_PADDING - playerUnitScroll

    love.graphics.stencil(function()
        love.graphics.rectangle(
            "fill",
            layout.boxX + BOX_PADDING,
            layout.boxY + BOX_PADDING,
            layout.availableWidth,
            layout.unitSize
        )
    end, "replace", 1)
    love.graphics.setStencilTest("greater", 0)

    for index = #layout.drawableUnits, 1, -1 do
        local unitId = layout.drawableUnits[index]
        local unitX = cursorX + (index - 1) * layout.unitSpacing

        drawUnit(unitId, unitX, layout.boxY + BOX_PADDING, layout.unitSize)
    end

    love.graphics.setStencilTest()
    love.graphics.setColor(1, 1, 1)

    local hoveredUnitId, hoveredIndex = getHoveredPlayerUnit(layout)

    if hoveredIndex ~= hoveredUnitIndex then
        hoveredUnitIndex = hoveredIndex

        if hoveredIndex then
            sfx.play("cardhover")
        end
    end

    if hoveredUnitId then
        drawUnitPreview(hoveredUnitId, layout)
    end
end

return unitRndr
