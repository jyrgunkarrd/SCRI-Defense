local playerOverlays = {}
local imageLoader = require("src.assets.image_loader")
local jaclDefinitions = require("data.jacl")
local mapElements = require("src.render.map_elements")

local TOP_BOX_Y = 30
local TOP_BOX_TILE_GAP = 18
local TOP_BOX_MIN_SIZE = 200
local SIDE_PANEL_WIDTH = 120
local SIDE_PANEL_GAP = 18
local SIDE_PANEL_PADDING = 14
local REACTOR_ICON_SIZE = 54
local REACTOR_VALUE_BOX_WIDTH = 72
local REACTOR_VALUE_BOX_HEIGHT = 44
local REACTOR_VALUE_BOX_GAP = 10
local PORTRAIT_PADDING = 10
local PORTRAIT_EXTENSIONS = { "webp", "png", "jpg", "jpeg" }

local portrait
local reactorIcon
local activeJacl
local currentReactorPoints = 0

local function findPortraitPath(jaclId)
    for _, extension in ipairs(PORTRAIT_EXTENSIONS) do
        local path = ("assets/images/jacl/%s.%s"):format(jaclId, extension)

        if love.filesystem.getInfo(path, "file") then
            return path
        end
    end
end

function playerOverlays.load()
    activeJacl = jaclDefinitions[1]

    if not activeJacl then
        return
    end

    local portraitPath = findPortraitPath(activeJacl.id)
    if portraitPath then
        portrait = imageLoader.newImage(portraitPath)
    end

    if love.filesystem.getInfo("assets/images/icons/overlay/reactor.png", "file") then
        reactorIcon = imageLoader.newImage("assets/images/icons/overlay/reactor.png")
    end
end

local function getTopBoxBounds()
    local screenWidth = love.graphics.getWidth()
    local _, tileY = mapElements.getTileBounds()
    local boxSize = math.max(TOP_BOX_MIN_SIZE, tileY - TOP_BOX_TILE_GAP - TOP_BOX_Y)
    local x = (screenWidth - boxSize) / 2

    return x, TOP_BOX_Y, boxSize
end

local function drawPortrait(x, y, boxSize)
    if not portrait then
        return
    end

    local availableSize = boxSize - PORTRAIT_PADDING * 2
    local scale = math.min(
        availableSize / portrait:getWidth(),
        availableSize / portrait:getHeight()
    )
    local width = portrait:getWidth() * scale
    local height = portrait:getHeight() * scale
    local portraitX = x + (boxSize - width) / 2
    local portraitY = y + (boxSize - height) / 2

    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(portrait, portraitX, portraitY, 0, scale, scale)
end

local function drawCenteredImage(image, x, y, size)
    if not image then
        return
    end

    local scale = math.min(size / image:getWidth(), size / image:getHeight())
    local width = image:getWidth() * scale
    local height = image:getHeight() * scale

    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(image, x + (size - width) / 2, y + (size - height) / 2, 0, scale, scale)
end

local function drawCenteredText(text, x, y, width, height)
    local font = love.graphics.getFont()
    local _, lines = font:getWrap(text, width)
    local textHeight = #lines * font:getHeight()

    love.graphics.printf(text, x, y + (height - textHeight) / 2, width, "center")
end

local function drawValueBox(text, x, y)
    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle("fill", x, y, REACTOR_VALUE_BOX_WIDTH, REACTOR_VALUE_BOX_HEIGHT)

    love.graphics.setColor(1, 1, 1)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", x, y, REACTOR_VALUE_BOX_WIDTH, REACTOR_VALUE_BOX_HEIGHT)
    drawCenteredText(text, x, y, REACTOR_VALUE_BOX_WIDTH, REACTOR_VALUE_BOX_HEIGHT)
end

local function drawReactorPanel(topBoxX, y, boxSize)
    local panelX = topBoxX - SIDE_PANEL_GAP - SIDE_PANEL_WIDTH
    local iconX = panelX + (SIDE_PANEL_WIDTH - REACTOR_ICON_SIZE) / 2
    local iconY = y + SIDE_PANEL_PADDING
    local valueBoxX = panelX + (SIDE_PANEL_WIDTH - REACTOR_VALUE_BOX_WIDTH) / 2
    local valueBoxesHeight = REACTOR_VALUE_BOX_HEIGHT * 2 + REACTOR_VALUE_BOX_GAP
    local valueBoxY = iconY + REACTOR_ICON_SIZE + (boxSize - SIDE_PANEL_PADDING - REACTOR_ICON_SIZE - valueBoxesHeight) / 2
    local reactorValue = activeJacl and activeJacl.reactor or 0

    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle("fill", panelX, y, SIDE_PANEL_WIDTH, boxSize)

    love.graphics.setColor(1, 1, 1)
    love.graphics.setLineWidth(6)
    love.graphics.rectangle("line", panelX, y, SIDE_PANEL_WIDTH, boxSize)

    drawCenteredImage(reactorIcon, iconX, iconY, REACTOR_ICON_SIZE)
    drawValueBox(("+" .. tostring(reactorValue)), valueBoxX, valueBoxY)
    drawValueBox(tostring(currentReactorPoints), valueBoxX, valueBoxY + REACTOR_VALUE_BOX_HEIGHT + REACTOR_VALUE_BOX_GAP)
end

function playerOverlays.drawTopBox()
    local x, y, boxSize = getTopBoxBounds()

    drawReactorPanel(x, y, boxSize)

    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle("fill", x, y, boxSize, boxSize)

    drawPortrait(x, y, boxSize)

    love.graphics.setColor(1, 1, 1)
    love.graphics.setLineWidth(6)
    love.graphics.rectangle("line", x, y, boxSize, boxSize)

    love.graphics.setColor(1, 1, 1)
end

return playerOverlays
