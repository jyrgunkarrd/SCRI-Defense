local mapElements = {}
local imageLoader = require("src.assets.image_loader")
local cardLogic = require("src.system.card_logic")
local locationFacGeo = require("src.system.location_fac_geo")
local cards = require("src.render.cards")
local sfx = require("src.audio.sfx")

local TILE_HORIZONTAL_MARGIN = 48
local TILE_HEIGHT = 656.25
local TILE_Y_OFFSET = 80
local TAB_COUNT = 10
local TAB_WIDTH = 190
local TAB_GAP = 4
local TAB_INSET = 18
local FACILITY_IMAGE_PADDING = 18
local RIGHT_BOX_WIDTH = 520
local RIGHT_BOX_HEIGHT = 140
local RIGHT_BOX_GAP = 12
local CENTER_SQUARE_GAP = FACILITY_IMAGE_PADDING
local FACILITY_IMAGE_EXTENSIONS = { "webp", "png", "jpg", "jpeg" }

local facilityImages = {}

local function findFacilityImagePath(facilityId)
    for _, extension in ipairs(FACILITY_IMAGE_EXTENSIONS) do
        local path = ("assets/images/facility/%s.%s"):format(facilityId, extension)

        if love.filesystem.getInfo(path, "file") then
            return path
        end
    end
end

function mapElements.load()
    for _, location in ipairs(locationFacGeo.getLocations()) do
        local facility = location.facility

        if facility and not facilityImages[facility.id] then
            local facilityImagePath = findFacilityImagePath(facility.id)

            if facilityImagePath then
                facilityImages[facility.id] = imageLoader.newImage(facilityImagePath)
            end
        end
    end
end

local function drawFacilityImage(tileX, tileY, tileWidth)
    local selectedFacility = locationFacGeo.getSelectedFacility()
    local facilityImage = selectedFacility and facilityImages[selectedFacility.id] or nil

    if not facilityImage then
        return nil
    end

    local availableHeight = TILE_HEIGHT - FACILITY_IMAGE_PADDING * 2
    local x = tileX + TAB_INSET + TAB_WIDTH + FACILITY_IMAGE_PADDING
    local rightBoxX = tileX + tileWidth - FACILITY_IMAGE_PADDING - RIGHT_BOX_WIDTH
    local centerSquareSize = (availableHeight - CENTER_SQUARE_GAP) / 2
    local availableWidth = rightBoxX - FACILITY_IMAGE_PADDING - centerSquareSize - FACILITY_IMAGE_PADDING - x
    local scale = math.min(
        availableHeight / facilityImage:getHeight(),
        math.max(0, availableWidth) / facilityImage:getWidth()
    )
    local width = facilityImage:getWidth() * scale
    local height = facilityImage:getHeight() * scale
    local y = tileY + (TILE_HEIGHT - height) / 2

    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(facilityImage, x, y, 0, scale, scale)

    return x, y, width, height
end

local function drawCenterSquares(tileX, tileY, imageX, imageWidth)
    if not imageX or not imageWidth then
        return
    end

    local availableHeight = TILE_HEIGHT - FACILITY_IMAGE_PADDING * 2
    local squareSize = (availableHeight - CENTER_SQUARE_GAP) / 2
    local squareX = imageX + imageWidth + FACILITY_IMAGE_PADDING
    local firstSquareY = tileY + FACILITY_IMAGE_PADDING

    love.graphics.setLineWidth(3)

    for index = 0, 1 do
        local squareY = firstSquareY + index * (squareSize + CENTER_SQUARE_GAP)

        love.graphics.setColor(0, 0, 0)
        love.graphics.rectangle("fill", squareX, squareY, squareSize, squareSize)

        love.graphics.setColor(1, 1, 1)
        love.graphics.rectangle("line", squareX, squareY, squareSize, squareSize)

        local placedCard = cardLogic.getPlacedCard(index + 1)

        if placedCard then
            cards.drawCardPortrait(placedCard, squareX, squareY, squareSize, squareSize)

            love.graphics.setColor(1, 1, 1)
            love.graphics.setLineWidth(3)
            love.graphics.rectangle("line", squareX, squareY, squareSize, squareSize)
        end
    end
end

local function drawTabs(tileX, tileY, tileWidth)
    local tabAreaHeight = TILE_HEIGHT - FACILITY_IMAGE_PADDING * 2
    local tabHeight = (tabAreaHeight - TAB_GAP * (TAB_COUNT - 1)) / TAB_COUNT
    local tabX = tileX + TAB_INSET
    local firstTabY = tileY + FACILITY_IMAGE_PADDING
    local selectedLocationIndex = locationFacGeo.getSelectedLocationIndex()

    for index = 1, TAB_COUNT do
        local tabY = firstTabY + (index - 1) * (tabHeight + TAB_GAP)
        local selected = index == selectedLocationIndex

        love.graphics.setColor(selected and 0 or 1, selected and 0 or 1, selected and 0 or 1)
        love.graphics.rectangle("fill", tabX, tabY, TAB_WIDTH, tabHeight)

        love.graphics.setColor(selected and 1 or 0, selected and 1 or 0, selected and 1 or 0)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", tabX, tabY, TAB_WIDTH, tabHeight)

        local label = locationFacGeo.getLocationLabel(index)
        local font = love.graphics.getFont()
        local _, wrappedLines = font:getWrap(label, TAB_WIDTH)
        local textHeight = #wrappedLines * font:getHeight()

        love.graphics.setColor(selected and 1 or 0, selected and 1 or 0, selected and 1 or 0)
        love.graphics.printf(label, tabX, tabY + (tabHeight - textHeight) / 2, TAB_WIDTH, "center")
    end
end

local function drawRightBoxes(tileX, tileY, tileWidth)
    love.graphics.setLineWidth(3)

    for index = 0, 1 do
        local topBoxX, topBoxY, topBoxWidth, topBoxHeight = mapElements.getRightBoxBounds(index + 3)
        local bottomBoxX, bottomBoxY, bottomBoxWidth, bottomBoxHeight = mapElements.getRightBoxBounds(index + 1)

        love.graphics.setColor(0, 0, 0)
        love.graphics.rectangle("fill", topBoxX, topBoxY, topBoxWidth, topBoxHeight)
        love.graphics.rectangle("fill", bottomBoxX, bottomBoxY, bottomBoxWidth, bottomBoxHeight)

        love.graphics.setColor(1, 1, 1)
        love.graphics.rectangle("line", topBoxX, topBoxY, topBoxWidth, topBoxHeight)
        love.graphics.rectangle("line", bottomBoxX, bottomBoxY, bottomBoxWidth, bottomBoxHeight)
    end
end

function mapElements.getTileBounds()
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    local tileWidth = math.max(0, screenWidth - TILE_HORIZONTAL_MARGIN * 2)
    local tileX = (screenWidth - tileWidth) / 2
    local tileY = (screenHeight - TILE_HEIGHT) / 2 + TILE_Y_OFFSET

    return tileX, tileY, tileWidth, TILE_HEIGHT
end

function mapElements.getRightBoxBounds(positionFromBottom)
    local tileX, tileY, tileWidth = mapElements.getTileBounds()
    local boxX = tileX + tileWidth - FACILITY_IMAGE_PADDING - RIGHT_BOX_WIDTH
    local topGroupY = tileY + FACILITY_IMAGE_PADDING
    local bottomGroupY = tileY + TILE_HEIGHT - FACILITY_IMAGE_PADDING - RIGHT_BOX_HEIGHT * 2 - RIGHT_BOX_GAP
    local positions = {
        bottomGroupY + RIGHT_BOX_HEIGHT + RIGHT_BOX_GAP,
        bottomGroupY,
        topGroupY + RIGHT_BOX_HEIGHT + RIGHT_BOX_GAP,
        topGroupY,
    }

    return boxX, positions[positionFromBottom or 1], RIGHT_BOX_WIDTH, RIGHT_BOX_HEIGHT
end

function mapElements.getCenterCardSlotBounds(slotIndex)
    local tileX, tileY, tileWidth = mapElements.getTileBounds()
    local selectedFacility = locationFacGeo.getSelectedFacility()
    local facilityImage = selectedFacility and facilityImages[selectedFacility.id] or nil

    if not facilityImage then
        return nil
    end

    local availableHeight = TILE_HEIGHT - FACILITY_IMAGE_PADDING * 2
    local facilityX = tileX + TAB_INSET + TAB_WIDTH + FACILITY_IMAGE_PADDING
    local rightBoxX = tileX + tileWidth - FACILITY_IMAGE_PADDING - RIGHT_BOX_WIDTH
    local squareSize = (availableHeight - CENTER_SQUARE_GAP) / 2
    local availableWidth = rightBoxX - FACILITY_IMAGE_PADDING - squareSize - FACILITY_IMAGE_PADDING - facilityX
    local facilityScale = math.min(
        availableHeight / facilityImage:getHeight(),
        math.max(0, availableWidth) / facilityImage:getWidth()
    )
    local facilityWidth = facilityImage:getWidth() * facilityScale
    local slotX = facilityX + facilityWidth + FACILITY_IMAGE_PADDING
    local slotY = tileY + FACILITY_IMAGE_PADDING + ((slotIndex or 1) - 1) * (squareSize + CENTER_SQUARE_GAP)

    return slotX, slotY, squareSize, squareSize
end

cardLogic.setSlotBoundsProvider(mapElements.getCenterCardSlotBounds)

function mapElements.getCenterCardSlotAtPosition(x, y)
    for slotIndex = 1, 2 do
        local slotX, slotY, slotWidth, slotHeight = mapElements.getCenterCardSlotBounds(slotIndex)

        if slotX
            and x >= slotX
            and x <= slotX + slotWidth
            and y >= slotY
            and y <= slotY + slotHeight then
            return slotIndex
        end
    end
end

local function getTabIndexAtPosition(x, y)
    local tileX, tileY = mapElements.getTileBounds()
    local tabAreaHeight = TILE_HEIGHT - FACILITY_IMAGE_PADDING * 2
    local tabHeight = (tabAreaHeight - TAB_GAP * (TAB_COUNT - 1)) / TAB_COUNT
    local tabX = tileX + TAB_INSET
    local firstTabY = tileY + FACILITY_IMAGE_PADDING

    if x < tabX or x > tabX + TAB_WIDTH then
        return nil
    end

    for index = 1, TAB_COUNT do
        local tabY = firstTabY + (index - 1) * (tabHeight + TAB_GAP)

        if y >= tabY and y <= tabY + tabHeight then
            return index
        end
    end
end

function mapElements.drawLargeTile()
    local x, y, tileWidth = mapElements.getTileBounds()

    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle("fill", x, y, tileWidth, TILE_HEIGHT)

    local imageX, _, imageWidth = drawFacilityImage(x, y, tileWidth)
    drawCenterSquares(x, y, imageX, imageWidth)
    drawRightBoxes(x, y, tileWidth)
    drawTabs(x, y, tileWidth)

    love.graphics.setColor(1, 1, 1)
    love.graphics.setLineWidth(6)
    love.graphics.rectangle("line", x, y, tileWidth, TILE_HEIGHT)

    love.graphics.setColor(1, 1, 1)
end

function mapElements.mousepressed(x, y, button)
    if button ~= 1 then
        return
    end

    local tabIndex = getTabIndexAtPosition(x, y)
    if tabIndex then
        locationFacGeo.selectLocation(tabIndex)
        sfx.play("button_select")
    end
end

return mapElements
