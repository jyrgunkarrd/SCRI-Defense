local input = {}
local mapElements = require("src.render.map_elements")
local handsDecks = require("src.system.hands_decks")
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
    if y ~= 0 then
        handsDecks.scrollPlayerHand(y)
    end
end

return input
