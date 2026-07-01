local cardLogic = {}

local placedCards = {
    nil,
    nil,
}
local draggingCard
local getSlotBounds

function cardLogic.startDrag(card, handIndex)
    if not card or not handIndex then
        return false
    end

    draggingCard = {
        card = card,
        handIndex = handIndex,
    }

    return true
end

function cardLogic.cancelDrag()
    draggingCard = nil
end

function cardLogic.getDraggingCard()
    return draggingCard
end

function cardLogic.isDragging()
    return draggingCard ~= nil
end

function cardLogic.setSlotBoundsProvider(provider)
    getSlotBounds = provider
end

function cardLogic.getPlacedCard(slotIndex)
    return placedCards[slotIndex]
end

function cardLogic.getPlacedCardAtPosition(x, y)
    if not getSlotBounds then
        return nil
    end

    for slotIndex, card in ipairs(placedCards) do
        if card then
            local slotX, slotY, slotWidth, slotHeight = getSlotBounds(slotIndex)

            if slotX
                and x >= slotX
                and x <= slotX + slotWidth
                and y >= slotY
                and y <= slotY + slotHeight then
                return card, slotIndex
            end
        end
    end
end

function cardLogic.placeDraggingCard(slotIndex)
    if not draggingCard or not slotIndex or placedCards[slotIndex] then
        cardLogic.cancelDrag()
        return nil
    end

    placedCards[slotIndex] = draggingCard.card

    local handIndex = draggingCard.handIndex
    draggingCard = nil

    return handIndex
end

return cardLogic
