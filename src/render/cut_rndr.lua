local cutRndr = {}
local combatLogic = require("src.system.combat_logic")
local unitRndr = require("src.render.unit_rndr")

local SLOT_WIDTH = 620
local SLOT_HEIGHT = 150
local SMALL_SLOT_HEIGHT = SLOT_HEIGHT / 2
local SLOT_GAP = 18
local SLOT_OUTLINE_WIDTH = 3
local SCREEN_MARGIN = 48
local PHASE_TRACKER_WIDTH = 212.5
local PHASE_TRACKER_GAP = 18
local PHASE_LABEL_HEIGHT = 34
local PHASE_LABEL_GAP = 7
local PHASE_GROUP_GAP = 14
local PHASE_LABEL_PADDING = 10
local PHASE_TEXT_MIN_SCALE = 0.55
local PHASE_TEXT_Y_OFFSET = -1
local COMBAT_BUTTON_WIDTH = 278
local COMBAT_BUTTON_HEIGHT = 44
local COMBAT_BUTTON_GAP = 16
local COMBAT_BUTTON_OUTLINE_WIDTH = 3
local COMBAT_BUTTON_TEXT_Y_OFFSET = -1

local function getSlotScrollKey(rowKey)
    return ("cutin_%s"):format(rowKey)
end

local function getCutInLayout()
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    local availableWidth = math.max(0, screenWidth - SCREEN_MARGIN * 2)
    local slotWidth = math.min(SLOT_WIDTH, math.max(0, availableWidth - PHASE_TRACKER_WIDTH - PHASE_TRACKER_GAP))
    local contentWidth = slotWidth + PHASE_TRACKER_WIDTH + PHASE_TRACKER_GAP
    local rowStackHeight = SLOT_HEIGHT * 2 + SMALL_SLOT_HEIGHT * 2 + SLOT_GAP * 3
    local totalHeight = rowStackHeight + COMBAT_BUTTON_GAP + COMBAT_BUTTON_HEIGHT
    local x = (screenWidth - contentWidth) / 2 + PHASE_TRACKER_WIDTH + PHASE_TRACKER_GAP
    local y = (screenHeight - totalHeight) / 2

    return {
        x = x,
        y = y,
        phaseX = x - PHASE_TRACKER_GAP - PHASE_TRACKER_WIDTH,
        slotWidth = slotWidth,
        slotHeight = SLOT_HEIGHT,
        smallSlotHeight = SMALL_SLOT_HEIGHT,
        gap = SLOT_GAP,
        rowStackHeight = rowStackHeight,
        buttonWidth = math.min(COMBAT_BUTTON_WIDTH, slotWidth),
        buttonHeight = COMBAT_BUTTON_HEIGHT,
        buttonGap = COMBAT_BUTTON_GAP,
    }
end

local function drawSlotFrame(x, y, width, height)
    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle("fill", x, y, width, height)

    love.graphics.setColor(1, 1, 1)
    love.graphics.setLineWidth(SLOT_OUTLINE_WIDTH)
    love.graphics.rectangle("line", x, y, width, height)
end

local function drawSlot(rowKey, x, y, width, height)
    drawSlotFrame(x, y, width, height)

    unitRndr.drawUnitSlot(rowKey, x, y, width, height, {
        scrollKey = getSlotScrollKey(rowKey),
        allowHover = false,
    })

    love.graphics.setColor(1, 1, 1)
    love.graphics.setLineWidth(SLOT_OUTLINE_WIDTH)
    love.graphics.rectangle("line", x, y, width, height)
end

local function drawPhaseLabel(text, x, y, width, height, selected)
    local font = love.graphics.getFont()
    local textWidth = font:getWidth(text)
    local textHeight = font:getHeight()
    local availableTextWidth = width - PHASE_LABEL_PADDING * 2
    local textScale = 1

    if textWidth > availableTextWidth then
        textScale = math.max(PHASE_TEXT_MIN_SCALE, availableTextWidth / textWidth)
    end

    local textX = x + (width - textWidth * textScale) / 2
    local textY = y + (height - textHeight * textScale) / 2 + PHASE_TEXT_Y_OFFSET

    if selected then
        love.graphics.setColor(0, 0, 0)
    else
        love.graphics.setColor(1, 1, 1)
    end

    love.graphics.rectangle("fill", x, y, width, height)

    if selected then
        love.graphics.setColor(1, 1, 1)
    else
        love.graphics.setColor(0, 0, 0)
    end

    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x, y, width, height)
    love.graphics.print(text, textX, textY, 0, textScale, textScale)
end

local function drawPhaseTracker(x, y, stackHeight)
    local labels = {
        {
            id = "fire_attack",
            text = "Fire Attack",
        },
        {
            id = "fire_damage",
            text = "Fire Damage",
        },
        {
            id = "steel_attack",
            text = "Steel Attack",
        },
        {
            id = "steel_damage",
            text = "Steel Damage",
        },
    }
    local totalHeight = PHASE_LABEL_HEIGHT * #labels + PHASE_LABEL_GAP * 2 + PHASE_GROUP_GAP
    local labelY = y + (stackHeight - totalHeight) / 2
    local selectedPhase = combatLogic.getSelectedPhase()

    for index, label in ipairs(labels) do
        drawPhaseLabel(label.text, x, labelY, PHASE_TRACKER_WIDTH, PHASE_LABEL_HEIGHT, label.id == selectedPhase)

        if index == 2 then
            labelY = labelY + PHASE_LABEL_HEIGHT + PHASE_GROUP_GAP
        else
            labelY = labelY + PHASE_LABEL_HEIGHT + PHASE_LABEL_GAP
        end
    end
end

local function getCombatDiceButtonBounds(layout, playerY)
    local buttonWidth = layout.buttonWidth
    local x = layout.x + (layout.slotWidth - buttonWidth) / 2
    local y = playerY + layout.slotHeight + layout.buttonGap

    return x, y, buttonWidth, layout.buttonHeight
end

local function isPointInBounds(pointX, pointY, x, y, width, height)
    return pointX >= x
        and pointX <= x + width
        and pointY >= y
        and pointY <= y + height
end

local function drawCombatDiceButton(layout, playerY)
    local x, y, width, height = getCombatDiceButtonBounds(layout, playerY)
    local mouseX, mouseY = love.mouse.getPosition()
    local hovered = isPointInBounds(mouseX, mouseY, x, y, width, height)
    local label = "Roll Combat Dice"
    local font = love.graphics.getFont()
    local textWidth = font:getWidth(label)
    local textHeight = font:getHeight()

    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle("fill", x, y, width, height)

    love.graphics.setColor(1, 1, 1)
    love.graphics.setLineWidth(COMBAT_BUTTON_OUTLINE_WIDTH)
    love.graphics.rectangle("line", x, y, width, height)

    if hovered then
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", x + 5, y + 5, width - 10, height - 10)
    end

    love.graphics.print(
        label,
        x + (width - textWidth) / 2,
        y + (height - textHeight) / 2 + COMBAT_BUTTON_TEXT_Y_OFFSET
    )
end

function cutRndr.drawCombatCutIn()
    if not combatLogic.isCutInActive() then
        return
    end

    local layout = getCutInLayout()
    local hostileY = layout.y
    local firstSmallSlotY = hostileY + layout.slotHeight + layout.gap
    local secondSmallSlotY = firstSmallSlotY + layout.smallSlotHeight + layout.gap
    local playerY = secondSmallSlotY + layout.smallSlotHeight + layout.gap

    love.graphics.setColor(0, 0, 0, 0.72)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())

    drawPhaseTracker(layout.phaseX, layout.y, layout.rowStackHeight)
    drawSlot("hostile", layout.x, hostileY, layout.slotWidth, layout.slotHeight)
    drawSlotFrame(layout.x, firstSmallSlotY, layout.slotWidth, layout.smallSlotHeight)
    drawSlotFrame(layout.x, secondSmallSlotY, layout.slotWidth, layout.smallSlotHeight)
    drawSlot("player", layout.x, playerY, layout.slotWidth, layout.slotHeight)
    drawCombatDiceButton(layout, playerY)

    love.graphics.setColor(1, 1, 1)
end

function cutRndr.isCursorOverCombatDiceButton(pointX, pointY)
    if not combatLogic.isCutInActive() then
        return false
    end

    local layout = getCutInLayout()
    local playerY = layout.y + layout.slotHeight + layout.gap * 3 + layout.smallSlotHeight * 2
    local buttonX, buttonY, buttonWidth, buttonHeight = getCombatDiceButtonBounds(layout, playerY)
    local mouseX, mouseY = pointX, pointY

    if not mouseX or not mouseY then
        mouseX, mouseY = love.mouse.getPosition()
    end

    return isPointInBounds(mouseX, mouseY, buttonX, buttonY, buttonWidth, buttonHeight)
end

local function getHoveredSlot()
    local layout = getCutInLayout()
    local mouseX, mouseY = love.mouse.getPosition()
    local slots = {
        {
            rowKey = "hostile",
            y = layout.y,
        },
        {
            rowKey = "player",
            y = layout.y + layout.slotHeight + layout.gap * 3 + layout.smallSlotHeight * 2,
        },
    }

    for _, slot in ipairs(slots) do
        if mouseX >= layout.x
            and mouseX <= layout.x + layout.slotWidth
            and mouseY >= slot.y
            and mouseY <= slot.y + layout.slotHeight then
            return slot.rowKey, layout.x, slot.y, layout.slotWidth, layout.slotHeight
        end
    end
end

function cutRndr.scrollCombatCutIn(direction)
    if not combatLogic.isCutInActive() then
        return false
    end

    local rowKey, x, y, width, height = getHoveredSlot()

    if not rowKey then
        return false
    end

    unitRndr.scrollUnitSlot(rowKey, x, y, width, height, getSlotScrollKey(rowKey), direction)
    return true
end

return cutRndr
