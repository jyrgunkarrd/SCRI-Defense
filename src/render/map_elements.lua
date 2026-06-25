local mapElements = {}

local TILE_WIDTH = 1125
local TILE_HEIGHT = 656.25

function mapElements.drawLargeTile()
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    local x = (screenWidth - TILE_WIDTH) / 2
    local y = (screenHeight - TILE_HEIGHT) / 2

    love.graphics.setColor(0.25, 0.42, 0.32)
    love.graphics.rectangle("fill", x, y, TILE_WIDTH, TILE_HEIGHT)

    love.graphics.setColor(0.54, 0.74, 0.58)
    love.graphics.setLineWidth(6)
    love.graphics.rectangle("line", x, y, TILE_WIDTH, TILE_HEIGHT)

    love.graphics.setColor(1, 1, 1)
end

return mapElements
