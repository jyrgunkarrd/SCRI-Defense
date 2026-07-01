local input = {}
local mapElements = require("src.render.map_elements")
local cards = require("src.render.cards")
local cardLogic = require("src.system.card_logic")
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
    if button ~= 1 then
        return
    end

    if combatLogic.isCutInActive() then
        if combatLogic.isShowingAttackRoll() then
            combatLogic.advanceAttackRoll()
            return
        end

        if combatLogic.isDamagePhase() then
            if combatLogic.isFireDamageResolutionActive() then
                return
            end

            if cutRndr.isFireDamageEliminationAnimating() then
                return
            end

            if cutRndr.handleFireDamageEliminationClick(x, y) then
                return
            end

            if combatLogic.isFireDamageEliminationActive() then
                return
            end

            if combatLogic.advanceCompletedDamagePhase() then
                return
            end

            combatLogic.dismissCutIn()
            return
        end

        if cutRndr.isCursorOverCombatDiceButton(x, y) then
            combatLogic.rollAttackDice()
            return
        end

        combatLogic.dismissCutIn()
        return
    end

    local handCard, handIndex = cards.getHandCardAtPosition(x, y)

    if handCard then
        cardLogic.startDrag(handCard, handIndex)
        return
    end

    mapElements.mousepressed(x, y, button)
end

function input.mousereleased(x, y, button)
    if button ~= 1 or not cardLogic.isDragging() then
        return
    end

    local slotIndex = mapElements.getCenterCardSlotAtPosition(x, y)
    local handIndex = slotIndex and cardLogic.placeDraggingCard(slotIndex) or nil

    if handIndex then
        handsDecks.removePlayerHandCard(handIndex)
        sfx.play("button_select")
    else
        cardLogic.cancelDrag()
    end
end

function input.wheelmoved(x, y)
    if y == 0 then
        return
    end

    if cardLogic.isDragging() then
        return
    elseif cutRndr.scrollCombatCutIn(y) then
        return
    elseif unitRndr.isCursorOverUnits() then
        unitRndr.scrollUnits(y)
    elseif cards.isCursorOverPlayerHand() then
        handsDecks.scrollPlayerHand(y)
    end
end

return input
