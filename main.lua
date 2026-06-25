local mapElements = require("src.render.map_elements")
local input = require("src.controls.input")

function love.load()
    love.graphics.setBackgroundColor(0.08, 0.09, 0.1)
end

function love.draw()
    mapElements.drawLargeTile()
end

function love.keypressed(key, scancode, isrepeat)
    input.keypressed(key, scancode, isrepeat)
end
