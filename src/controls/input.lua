local input = {}
local mapElements = require("src.render.map_elements")
local cards = require("src.render.cards")
local combatLogic = require("src.system.combat_logic")
local cutRndr = require("src.render.cut_rndr")
local devCmd = require("src.controls.dev_cmd")
local handsDecks = require("src.system.hands_decks")
local unitRndr = require("src.render.unit_rndr")
local sfx = require("src.audio.sfx")

function input.keypressed(key)
    if devCmd.keypressed(key) then
        return
    elseif key == "escape" then
        love.event.quit()
    elseif key == "tab" then
        handsDecks.togglePlayerHandExtended()
        sfx.play("tab_view")
    end
end

function input.mousepressed(x, y, button)
    if combatLogic.isCutInActive() then
        if cutRndr.isCursorOverCombatDiceButton(x, y) then
            return
        end

        combatLogic.dismissCutIn()
        return
    end

    mapElements.mousepressed(x, y, button)
end

function input.wheelmoved(x, y)
    if y == 0 then
        return
    end

    if cutRndr.scrollCombatCutIn(y) then
        return
    elseif unitRndr.isCursorOverUnits() then
        unitRndr.scrollUnits(y)
    elseif cards.isCursorOverPlayerHand() then
        handsDecks.scrollPlayerHand(y)
    end
end

return input
