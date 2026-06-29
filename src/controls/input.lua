local input = {}
local mapElements = require("src.render.map_elements")
local cards = require("src.render.cards")
local handsDecks = require("src.system.hands_decks")
local unitRndr = require("src.render.unit_rndr")
local sfx = require("src.audio.sfx")

function input.keypressed(key)
    if key == "escape" then
        love.event.quit()
    elseif key == "tab" then
        handsDecks.togglePlayerHandExtended()
        sfx.play("tab_view")
    end
end

function input.mousepressed(x, y, button)
    mapElements.mousepressed(x, y, button)
end

function input.wheelmoved(x, y)
    if y == 0 then
        return
    end

    if unitRndr.isCursorOverPlayerUnits() then
        unitRndr.scrollPlayerUnits(y)
    elseif cards.isCursorOverPlayerHand() then
        handsDecks.scrollPlayerHand(y)
    end
end

return input
