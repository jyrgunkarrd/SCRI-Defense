local diceRndr = {}
local imageLoader = require("src.assets.image_loader")

local FACE_SIZE = 52
local FACE_GAP = 6
local FACE_COLUMNS = 3
local FACE_ROWS = 2
local FACE_OUTLINE_WIDTH = 3
local PANEL_PADDING = 6
local ICON_SIZE = 22
local ICON_STEP = 16
local HYBRID_PULSE_SPEED = 3.6
local ICON_PATHS = {
    ammo = "assets/images/icons/dice/ammo.png",
    blank = "assets/images/icons/dice/blank.png",
    damage = "assets/images/icons/dice/damage.png",
    shield = "assets/images/icons/dice/shield.png",
    tac = "assets/images/icons/dice/tac.png",
}

local icons = {}

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

local function drawIcon(icon, x, y, alpha)
    if not icon then
        return
    end

    local scale = math.min(ICON_SIZE / icon:getWidth(), ICON_SIZE / icon:getHeight())
    local width = icon:getWidth() * scale
    local height = icon:getHeight() * scale

    love.graphics.setColor(1, 1, 1, alpha or 1)
    love.graphics.draw(icon, x - width / 2, y - height / 2, 0, scale, scale)
end

local function drawFaceIcons(face, x, y)
    if not face or not face.type then
        return
    end

    local iconCount = math.max(1, math.floor(face.value or 1))
    local centerX = x + FACE_SIZE / 2
    local centerY = y + FACE_SIZE / 2
    local firstOffset = -((iconCount - 1) * ICON_STEP) / 2
    local pulse = (math.sin(love.timer.getTime() * HYBRID_PULSE_SPEED) + 1) / 2

    for index = 1, iconCount do
        local offset = firstOffset + (index - 1) * ICON_STEP
        local iconX = centerX + offset
        local iconY = centerY + offset

        if face.htype then
            drawIcon(icons[face.type], iconX, iconY, 1 - pulse)
            drawIcon(icons[face.htype], iconX, iconY, pulse)
        else
            drawIcon(icons[face.type], iconX, iconY, 1)
        end
    end
end

function diceRndr.load()
    for iconType, path in pairs(ICON_PATHS) do
        if love.filesystem.getInfo(path, "file") then
            icons[iconType] = imageLoader.newImage(path)
        end
    end
end

function diceRndr.getPanelSize()
    return FACE_COLUMNS * FACE_SIZE + (FACE_COLUMNS - 1) * FACE_GAP,
        FACE_ROWS * FACE_SIZE + (FACE_ROWS - 1) * FACE_GAP
end

function diceRndr.drawDie(die, x, y)
    if not die then
        return
    end

    local r, g, b = htmlColorToRgb(die.color)
    local panelWidth, panelHeight = diceRndr.getPanelSize()

    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle("fill", x - PANEL_PADDING, y - PANEL_PADDING, panelWidth + PANEL_PADDING * 2, panelHeight + PANEL_PADDING * 2)

    for index = 1, FACE_COLUMNS * FACE_ROWS do
        local column = (index - 1) % FACE_COLUMNS
        local row = math.floor((index - 1) / FACE_COLUMNS)
        local faceX = x + column * (FACE_SIZE + FACE_GAP)
        local faceY = y + row * (FACE_SIZE + FACE_GAP)
        local face = die.faces and die.faces[("F%d"):format(index)] or nil

        love.graphics.setColor(0, 0, 0)
        love.graphics.rectangle("fill", faceX, faceY, FACE_SIZE, FACE_SIZE)

        love.graphics.setColor(r, g, b)
        love.graphics.setLineWidth(FACE_OUTLINE_WIDTH)
        love.graphics.rectangle("line", faceX, faceY, FACE_SIZE, FACE_SIZE)

        drawFaceIcons(face, faceX, faceY)
    end

    love.graphics.setColor(1, 1, 1)
end

return diceRndr
