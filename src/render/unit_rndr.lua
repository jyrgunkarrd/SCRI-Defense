local unitRndr = {}
local imageLoader = require("src.assets.image_loader")
local locationFacGeo = require("src.system.location_fac_geo")
local mapElements = require("src.render.map_elements")
local diceRndr = require("src.render.dice_rndr")
local sfx = require("src.audio.sfx")

local UNIT_IMAGE_EXTENSIONS = { "webp", "png", "jpg", "jpeg" }
local UNIT_ICON_EXTENSIONS = { "png", "webp", "jpg", "jpeg" }
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
local RATK_BADGE_ICON_PADDING_FACTOR = 0.06
local RATK_BADGE_ICON_SCALE_MULTIPLIER = 1.25
local PREVIEW_GAP = 16
local PREVIEW_IMAGE_SIZE = 168
local PREVIEW_LABEL_HEIGHT = 34
local PREVIEW_LABEL_PADDING = 14
local PREVIEW_LABEL_GAP = 6
local PREVIEW_DIE_GAP = 10
local TAG_LABEL_HEIGHT = 24
local TAG_LABEL_GAP = 5
local TAG_LABEL_TOP_GAP = 10
local TAG_LABEL_OUTLINE_WIDTH = 2
local TAG_TEXT_MIN_SCALE = 0.55
local TAG_TEXT_Y_OFFSET = -2
local UNIT_ROW_ORDER = { "hostile", "player" }
local UNIT_ROW_CONFIGS = {
    hostile = {
        field = "hostileunits",
        boxFromBottom = 3,
    },
    player = {
        field = "playerunits",
        boxFromBottom = TARGET_BOX_FROM_BOTTOM,
    },
}

local unitIndex
local unitTesting
local diceIndex = {}
local unitImages = {}
local unitIconImages = {}
local unitRowScrolls = {}
local hoveredUnitKey

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

local function findUnitIconPath(iconId)
    for _, extension in ipairs(UNIT_ICON_EXTENSIONS) do
        local path = ("assets/images/icons/units/%s.%s"):format(iconId, extension)

        if love.filesystem.getInfo(path, "file") then
            return path
        end
    end
end

local function loadUnitIcon(iconId)
    if not iconId or unitIconImages[iconId] ~= nil then
        return
    end

    local iconPath = findUnitIconPath(iconId)
    unitIconImages[iconId] = iconPath and imageLoader.newImage(iconPath) or false
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

    return x + (size - width) / 2, y + (size - height) / 2, width, height
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

local function round(value)
    return math.floor(value + 0.5)
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

local function getUnitRatk(unitId)
    local unit = unitIndex and unitIndex.byId[unitId]

    return unit and unit.ratk
end

local function getUnitBadgeSize(size)
    return round(math.max(DIE_BADGE_MIN_SIZE, math.min(DIE_BADGE_MAX_SIZE, size * DIE_BADGE_SIZE_FACTOR)))
end

local function getUnitBadgeFrame(x, y, width, height, size)
    local badgeSize = getUnitBadgeSize(size)
    local badgeRight = round(x + width)
    local badgeX = badgeRight - badgeSize
    local badgeY = round(y)

    return badgeX, badgeY, badgeSize
end

local function drawDieBadge(unitId, x, y, width, height, size)
    local dieId = getUnitPrimaryDieId(unitId)
    local die = dieId and diceIndex[dieId]

    if not die or not die.color then
        return
    end

    local badgeX, badgeY, badgeSize = getUnitBadgeFrame(x, y, width, height, size)
    local r, g, b = htmlColorToRgb(die.color)

    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle("fill", badgeX, badgeY, badgeSize, badgeSize)

    love.graphics.setColor(r, g, b)
    love.graphics.rectangle(
        "fill",
        badgeX + DIE_BADGE_OUTLINE_WIDTH,
        badgeY + DIE_BADGE_OUTLINE_WIDTH,
        badgeSize - DIE_BADGE_OUTLINE_WIDTH * 2,
        badgeSize - DIE_BADGE_OUTLINE_WIDTH * 2
    )
end

local function drawRatkBadge(unitId, x, y, width, height, size)
    local ratk = getUnitRatk(unitId)
    local icon = ratk and unitIconImages[ratk]

    if not icon then
        return
    end

    local badgeX, dieBadgeY, badgeSize = getUnitBadgeFrame(x, y, width, height, size)
    local badgeY = dieBadgeY + badgeSize
    local iconPadding = round(badgeSize * RATK_BADGE_ICON_PADDING_FACTOR)
    local iconSize = badgeSize - iconPadding * 2
    local iconScale = math.min(iconSize / icon:getWidth(), iconSize / icon:getHeight())
    local iconWidth = round(icon:getWidth() * iconScale * RATK_BADGE_ICON_SCALE_MULTIPLIER)
    local iconHeight = round(icon:getHeight() * iconScale * RATK_BADGE_ICON_SCALE_MULTIPLIER)
    local iconX = round(badgeX + (badgeSize - iconWidth) / 2)
    local iconY = round(badgeY + (badgeSize - iconHeight) / 2)

    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle("fill", badgeX, badgeY, badgeSize, badgeSize)

    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle("fill", badgeX, badgeY, badgeSize, DIE_BADGE_OUTLINE_WIDTH)
    love.graphics.rectangle("fill", badgeX, badgeY + badgeSize - DIE_BADGE_OUTLINE_WIDTH, badgeSize, DIE_BADGE_OUTLINE_WIDTH)
    love.graphics.rectangle("fill", badgeX, badgeY, DIE_BADGE_OUTLINE_WIDTH, badgeSize)
    love.graphics.rectangle("fill", badgeX + badgeSize - DIE_BADGE_OUTLINE_WIDTH, badgeY, DIE_BADGE_OUTLINE_WIDTH, badgeSize)

    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(icon, iconX, iconY, 0, iconWidth / icon:getWidth(), iconHeight / icon:getHeight())

end

local function drawUnit(unitId, x, y, size)
    local imageX = x
    local imageY = y
    local imageWidth = size
    local imageHeight = size

    if unitImages[unitId] then
        imageX, imageY, imageWidth, imageHeight = drawUnitImage(unitId, x, y, size)
    else
        drawMissingUnit(unitId, x, y, size)
    end

    drawDieBadge(unitId, imageX, imageY, imageWidth, imageHeight, size)
    drawRatkBadge(unitId, imageX, imageY, imageWidth, imageHeight, size)
end

local function getUnitName(unitId)
    local unit = unitIndex and unitIndex.byId[unitId]

    return unit and unit.name or unitId
end

local function getUnitTags(unitId)
    local unit = unitIndex and unitIndex.byId[unitId]

    return unit and unit.tags or {}
end

local function drawTagLabels(unitId, x, y, width)
    for index, tag in ipairs(getUnitTags(unitId)) do
        local labelY = y + (index - 1) * (TAG_LABEL_HEIGHT + TAG_LABEL_GAP)
        local font = love.graphics.getFont()
        local textWidth = font:getWidth(tag)
        local textHeight = font:getHeight()
        local availableTextWidth = width - PREVIEW_LABEL_PADDING * 2
        local textScale = 1

        if textWidth > availableTextWidth then
            textScale = math.max(TAG_TEXT_MIN_SCALE, availableTextWidth / textWidth)
        end

        local textX = x + (width - textWidth * textScale) / 2
        local textY = labelY + (TAG_LABEL_HEIGHT - textHeight * textScale) / 2 + TAG_TEXT_Y_OFFSET

        love.graphics.setColor(1, 1, 1)
        love.graphics.rectangle("fill", x, labelY, width, TAG_LABEL_HEIGHT)

        love.graphics.setColor(0, 0, 0)
        love.graphics.setLineWidth(TAG_LABEL_OUTLINE_WIDTH)
        love.graphics.rectangle("line", x, labelY, width, TAG_LABEL_HEIGHT)
        love.graphics.print(tag, textX, textY, 0, textScale, textScale)
    end
end

local function getTagLabelsHeight(unitId)
    local tagCount = #getUnitTags(unitId)

    if tagCount == 0 then
        return 0
    end

    return tagCount * TAG_LABEL_HEIGHT + (tagCount - 1) * TAG_LABEL_GAP
end

local function getDrawableUnits(entries, facilityId)
    local drawableUnits = {}

    for _, entry in ipairs(entries or {}) do
        if entry.fac == facilityId and unitIndex.byId[entry.unit] then
            local unitCount = math.max(1, math.floor(entry.num or 1))

            for _ = 1, unitCount do
                table.insert(drawableUnits, entry.unit)
            end
        end
    end

    return drawableUnits
end

local function getUnitOverlapSpacing(unitCount, unitSize, availableWidth)
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

local function getUnitGroupCount(drawableUnits)
    local groupCount = 0
    local previousUnitId

    for _, unitId in ipairs(drawableUnits) do
        if unitId ~= previousUnitId then
            groupCount = groupCount + 1
            previousUnitId = unitId
        end
    end

    return groupCount
end

local function getContentWidth(drawableUnits, unitSize, unitSpacing)
    if #drawableUnits == 0 then
        return 0
    end

    local width = unitSize
    local previousUnitId = drawableUnits[1]

    for index = 2, #drawableUnits do
        local unitId = drawableUnits[index]

        if unitId ~= previousUnitId then
            width = width + unitSize + UNIT_GAP
        else
            width = width + unitSpacing
        end

        previousUnitId = unitId
    end

    return width
end

local function getUnitDrawItems(drawableUnits, unitSize, unitSpacing)
    local drawItems = {}
    local x = 0
    local previousUnitId

    for index, unitId in ipairs(drawableUnits) do
        if index > 1 then
            if unitId ~= previousUnitId then
                x = x + unitSize + UNIT_GAP
            else
                x = x + unitSpacing
            end
        end

        table.insert(drawItems, {
            unitId = unitId,
            index = index,
            x = x,
        })

        previousUnitId = unitId
    end

    return drawItems
end

local function getUnitRowLayout(rowKey, overrideBounds, scrollKey)
    local rowConfig = UNIT_ROW_CONFIGS[rowKey]
    local selectedFacility = locationFacGeo.getSelectedFacility()

    if not rowConfig or not selectedFacility or not unitTesting then
        return nil
    end

    local boxX, boxY, boxWidth, boxHeight

    if overrideBounds then
        boxX, boxY, boxWidth, boxHeight = overrideBounds.x, overrideBounds.y, overrideBounds.width, overrideBounds.height
    else
        boxX, boxY, boxWidth, boxHeight = mapElements.getRightBoxBounds(rowConfig.boxFromBottom)
    end

    local unitSize = boxHeight - BOX_PADDING * 2
    local availableWidth = boxWidth - BOX_PADDING * 2
    local drawableUnits = getDrawableUnits(unitTesting[rowConfig.field], selectedFacility.id)
    local groupCount = getUnitGroupCount(drawableUnits)
    local groupedGapWidth = math.max(0, groupCount - 1) * (unitSize + UNIT_GAP)
    local overlapAvailableWidth = math.max(unitSize, availableWidth - groupedGapWidth)
    local unitSpacing = getUnitOverlapSpacing(#drawableUnits - math.max(0, groupCount - 1), unitSize, overlapAvailableWidth)
    local contentWidth = getContentWidth(drawableUnits, unitSize, unitSpacing)
    local drawItems = getUnitDrawItems(drawableUnits, unitSize, unitSpacing)

    local maxScroll = math.max(0, contentWidth - availableWidth)
    local effectiveScrollKey = scrollKey or rowKey
    unitRowScrolls[effectiveScrollKey] = math.max(0, math.min(unitRowScrolls[effectiveScrollKey] or 0, maxScroll))

    return {
        rowKey = rowKey,
        scrollKey = effectiveScrollKey,
        boxX = boxX,
        boxY = boxY,
        boxWidth = boxWidth,
        boxHeight = boxHeight,
        unitSize = unitSize,
        availableWidth = availableWidth,
        drawableUnits = drawableUnits,
        drawItems = drawItems,
        unitSpacing = unitSpacing,
        maxScroll = maxScroll,
        scroll = unitRowScrolls[effectiveScrollKey],
    }
end

local function getHoveredUnit(layout)
    if not layout or #layout.drawItems == 0 then
        return nil
    end

    local mouseX, mouseY = love.mouse.getPosition()

    if mouseX < layout.boxX
        or mouseX > layout.boxX + layout.boxWidth
        or mouseY < layout.boxY
        or mouseY > layout.boxY + layout.boxHeight then
        return nil
    end

    for _, drawItem in ipairs(layout.drawItems) do
        local unitX = layout.boxX + BOX_PADDING - layout.scroll + drawItem.x
        local unitY = layout.boxY + BOX_PADDING

        if mouseX >= unitX
            and mouseX <= unitX + layout.unitSize
            and mouseY >= unitY
            and mouseY <= unitY + layout.unitSize then
            return drawItem.unitId, drawItem.index, ("%s:%d"):format(layout.rowKey, drawItem.index)
        end
    end
end

local function drawUnitPreview(unitId, layout)
    local dieId = getUnitPrimaryDieId(unitId)
    local die = dieId and diceIndex[dieId]
    local diePanelWidth, diePanelHeight = diceRndr.getPanelSize()
    local diePanelPadding = diceRndr.getPanelPadding()
    local tagLabelsHeight = getTagLabelsHeight(unitId)
    local rightColumnHeight = PREVIEW_IMAGE_SIZE
    local rightColumnWidth = 0

    if die then
        rightColumnWidth = diePanelWidth + diePanelPadding * 2
        rightColumnHeight = diePanelHeight + diePanelPadding * 2

        if tagLabelsHeight > 0 then
            rightColumnHeight = diePanelPadding + diePanelHeight + TAG_LABEL_TOP_GAP + tagLabelsHeight
        end
    end

    local imageSize = rightColumnHeight
    local previewWidth = imageSize

    if die then
        previewWidth = previewWidth + PREVIEW_DIE_GAP + rightColumnWidth
    end

    local centerX = layout.boxX + layout.boxWidth / 2
    local previewX = centerX - previewWidth / 2
    local imageX = previewX
    local imageY = layout.boxY - PREVIEW_GAP - imageSize
    local labelX = previewX
    local labelY = imageY - PREVIEW_LABEL_GAP - PREVIEW_LABEL_HEIGHT

    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle("fill", labelX, labelY, previewWidth, PREVIEW_LABEL_HEIGHT)

    love.graphics.setColor(1, 1, 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", labelX, labelY, previewWidth, PREVIEW_LABEL_HEIGHT)
    love.graphics.printf(getUnitName(unitId), labelX + PREVIEW_LABEL_PADDING, labelY + 5, previewWidth - PREVIEW_LABEL_PADDING * 2, "center")

    drawUnit(unitId, imageX, imageY, imageSize)

    if die then
        local diePanelX = imageX + imageSize + PREVIEW_DIE_GAP + diePanelPadding
        local diePanelY = imageY + diePanelPadding

        diceRndr.drawDie(die, diePanelX, diePanelY)

        if tagLabelsHeight > 0 then
            drawTagLabels(unitId, diePanelX, diePanelY + diePanelHeight + TAG_LABEL_TOP_GAP, diePanelWidth)
        end
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

    for _, rowConfig in pairs(UNIT_ROW_CONFIGS) do
        for _, entry in ipairs(unitTesting[rowConfig.field] or {}) do
            local unit = unitIndex.byId[entry.unit]

            if unit then
                loadUnitImage(entry.unit)
                loadUnitIcon(unit.ratk)
            end
        end
    end
end

local function getHoveredUnitRowLayout()
    for _, rowKey in ipairs(UNIT_ROW_ORDER) do
        local layout = getUnitRowLayout(rowKey)

        if layout then
            local mouseX, mouseY = love.mouse.getPosition()

            if mouseX >= layout.boxX
                and mouseX <= layout.boxX + layout.boxWidth
                and mouseY >= layout.boxY
                and mouseY <= layout.boxY + layout.boxHeight then
                return layout
            end
        end
    end
end

function unitRndr.isCursorOverUnits()
    return getHoveredUnitRowLayout() ~= nil
end

function unitRndr.isCursorOverPlayerUnits()
    return unitRndr.isCursorOverUnits()
end

function unitRndr.scrollUnits(direction)
    local layout = getHoveredUnitRowLayout()

    if not layout or layout.maxScroll <= 0 then
        return
    end

    unitRowScrolls[layout.scrollKey] = math.max(0, math.min((unitRowScrolls[layout.scrollKey] or 0) + direction * UNIT_SCROLL_STEP, layout.maxScroll))
end

function unitRndr.scrollUnitSlot(rowKey, x, y, width, height, scrollKey, direction)
    local layout = getUnitRowLayout(rowKey, {
        x = x,
        y = y,
        width = width,
        height = height,
    }, scrollKey)

    if not layout or layout.maxScroll <= 0 then
        return
    end

    unitRowScrolls[layout.scrollKey] = math.max(0, math.min((unitRowScrolls[layout.scrollKey] or 0) + direction * UNIT_SCROLL_STEP, layout.maxScroll))
end

function unitRndr.scrollPlayerUnits(direction)
    unitRndr.scrollUnits(direction)
end

local function drawUnitRow(layout)
    if not layout or #layout.drawItems == 0 then
        return
    end

    local cursorX = layout.boxX + BOX_PADDING - layout.scroll

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

    for index = #layout.drawItems, 1, -1 do
        local drawItem = layout.drawItems[index]
        local unitX = cursorX + drawItem.x

        drawUnit(drawItem.unitId, unitX, layout.boxY + BOX_PADDING, layout.unitSize)
    end

    love.graphics.setStencilTest()
    love.graphics.setColor(1, 1, 1)
end

function unitRndr.drawUnitSlot(rowKey, x, y, width, height, options)
    options = options or {}

    local layout = getUnitRowLayout(rowKey, {
        x = x,
        y = y,
        width = width,
        height = height,
    }, options.scrollKey)

    drawUnitRow(layout)
end

function unitRndr.drawPlayerUnits()
    local hoveredUnitId
    local hoveredKey
    local hoveredLayout

    for _, rowKey in ipairs(UNIT_ROW_ORDER) do
        local layout = getUnitRowLayout(rowKey)

        drawUnitRow(layout)

        local unitId, _, unitKey = getHoveredUnit(layout)
        if unitId then
            hoveredUnitId = unitId
            hoveredKey = unitKey
            hoveredLayout = layout
        end
    end

    if hoveredKey ~= hoveredUnitKey then
        hoveredUnitKey = hoveredKey

        if hoveredKey then
            sfx.play("cardhover")
        end
    end

    if hoveredUnitId then
        drawUnitPreview(hoveredUnitId, hoveredLayout)
    end
end

return unitRndr
