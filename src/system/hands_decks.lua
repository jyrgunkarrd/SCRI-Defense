local handsDecks = {}
local handTesting = require("data.handtesting")

local DEFAULT_HAND_SIZE = 7
local HAND_SCROLL_STEP = 140

local playerHand = {}
local playerHandExtended = false
local playerHandScroll = 0

local function pickRandomCard(cardIndex)
    if not cardIndex or #cardIndex.all == 0 then
        return nil
    end

    return cardIndex.all[love.math.random(#cardIndex.all)]
end

function handsDecks.buildPlayerHand(cardIndex)
    playerHand = {}
    playerHandScroll = 0
    local handSize = handTesting.handsize or DEFAULT_HAND_SIZE

    for _ = 1, handSize do
        local card = pickRandomCard(cardIndex)

        if card then
            table.insert(playerHand, card)
        end
    end
end

function handsDecks.getPlayerHand()
    return playerHand
end

function handsDecks.togglePlayerHandExtended()
    playerHandExtended = not playerHandExtended
end

function handsDecks.isPlayerHandExtended()
    return playerHandExtended
end

function handsDecks.scrollPlayerHand(direction)
    playerHandScroll = playerHandScroll + direction * HAND_SCROLL_STEP
end

function handsDecks.setPlayerHandScroll(scroll)
    playerHandScroll = scroll
end

function handsDecks.getPlayerHandScroll()
    return playerHandScroll
end

return handsDecks
