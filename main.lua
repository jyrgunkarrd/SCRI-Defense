local mapElements = require("src.render.map_elements")
local playerOverlays = require("src.render.player_overlays")
local cards = require("src.render.cards")
local unitRndr = require("src.render.unit_rndr")
local cutRndr = require("src.render.cut_rndr")
local input = require("src.controls.input")

function love.load()
    love.graphics.setDefaultFilter("linear", "linear", 1)
    love.graphics.setFont(love.graphics.newFont("assets/fonts/Furore.otf", 20))
    love.graphics.setBackgroundColor(0.08, 0.09, 0.1)
    mapElements.load()
    playerOverlays.load()
    cards.load()
    unitRndr.load()
end

function love.draw()
    mapElements.drawLargeTile()
    unitRndr.drawPlayerUnits()
    playerOverlays.drawTopBox()
    cards.drawFocusedCard()
    cards.drawPlayerHand()
    cutRndr.drawCombatCutIn()
end

function love.keypressed(key, scancode, isrepeat)
    input.keypressed(key, scancode, isrepeat)
end

function love.mousepressed(x, y, button, istouch, presses)
    input.mousepressed(x, y, button, istouch, presses)
end

function love.wheelmoved(x, y)
    input.wheelmoved(x, y)
end
