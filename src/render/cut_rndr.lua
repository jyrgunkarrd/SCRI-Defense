local cutRndr = {}
local combatLogic = require("src.system.combat_logic")
local imageLoader = require("src.assets.image_loader")
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
local RESULT_REVEAL_MARGIN = 48
local RESULT_REVEAL_IMAGE_SIZE = 300
local RESULT_REVEAL_PANEL_WIDTH = 360
local RESULT_REVEAL_PANEL_GAP = 14
local RESULT_REVEAL_PANEL_PADDING = 12
local RESULT_ICON_SIZE = 24
local RESULT_ICON_GAP = 8
local RESULT_ICON_COLUMNS = 10
local RESULT_ICON_ANIM_DURATION = 0.35
local RESULT_ICON_ANIM_STAGGER = 0.025
local RESULT_ICON_ANIM_DROP = 10
local FIRE_DAMAGE_PUNCH_IMPACT = 0.72
local FIRE_DAMAGE_JITTER_AMPLITUDE = 5
local FIRE_DAMAGE_JITTER_SPEED = 82
local TALLY_ICON_SIZE = 22
local TALLY_GROUP_GAP = 24
local TALLY_TEXT_GAP = 7
local TALLY_ROW_PADDING_X = 18
local TALLY_ROW_TEXT_Y_OFFSET = -2
local ELIMINATION_PROMPT_HEIGHT = 34
local ELIMINATION_PROMPT_GAP = 10
local ELIMINATION_PROMPT_PADDING = 14
local ELIMINATION_PROMPT_TEXT_Y_OFFSET = -1
local ELIMINATION_ANIM_DURATION = 0.2
local ELIMINATION_WIPE_FADE = 0.35

local DICE_ICON_PATHS = {
    ammo = "assets/images/icons/dice/ammo.png",
    blank = "assets/images/icons/dice/blank.png",
    damage = "assets/images/icons/dice/damage.png",
    shield = "assets/images/icons/dice/shield.png",
    tac = "assets/images/icons/dice/tac.png",
}
local TALLY_ICON_PATHS = {
    ammo = "assets/images/icons/dice/ammo_rec.png",
    damage = "assets/images/icons/dice/damage_rec.png",
    shield = "assets/images/icons/dice/shield_rec.png",
    tac = "assets/images/icons/dice/tac_rec.png",
}
local diceIcons = {}
local tallyIcons = {}
local eliminationAnims = {}

local function getSlotScrollKey(rowKey)
    return ("cutin_%s"):format(rowKey)
end

local function getIcon(path)
    if not path then
        return nil
    end

    if diceIcons[path] == nil then
        diceIcons[path] = love.filesystem.getInfo(path, "file") and imageLoader.newImage(path) or false
    end

    return diceIcons[path] or nil
end

local function getTallyIcon(resultType)
    local path = TALLY_ICON_PATHS[resultType]

    if path and tallyIcons[path] == nil then
        tallyIcons[path] = love.filesystem.getInfo(path, "file") and imageLoader.newImage(path) or false
    end

    if path and tallyIcons[path] then
        return tallyIcons[path]
    end

    return getIcon(DICE_ICON_PATHS[resultType])
end

local function drawImageCentered(image, x, y, size, alpha)
    if not image then
        return
    end

    local scale = math.min(size / image:getWidth(), size / image:getHeight())
    local width = image:getWidth() * scale
    local height = image:getHeight() * scale

    love.graphics.setColor(1, 1, 1, alpha or 1)
    love.graphics.draw(image, x + (size - width) / 2, y + (size - height) / 2, 0, scale, scale)
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

local function drawSlot(rowKey, x, y, width, height, options)
    options = options or {}

    drawSlotFrame(x, y, width, height)

    unitRndr.drawUnitSlot(rowKey, x, y, width, height, {
        scrollKey = getSlotScrollKey(rowKey),
        allowHover = false,
        hiddenUnitKeys = options.hiddenUnitKeys,
    })

    love.graphics.setColor(1, 1, 1)
    love.graphics.setLineWidth(SLOT_OUTLINE_WIDTH)
    love.graphics.rectangle("line", x, y, width, height)
end

local function drawResultIcon(resultType, x, y, size, alpha)
    drawImageCentered(getIcon(DICE_ICON_PATHS[resultType]), x, y, size, alpha)
end

local function clamp(value, minValue, maxValue)
    return math.max(minValue, math.min(value, maxValue))
end

local function easeOutBack(progress)
    local c1 = 1.70158
    local c3 = c1 + 1

    return 1 + c3 * math.pow(progress - 1, 3) + c1 * math.pow(progress - 1, 2)
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
    local label = "Roll Attack Dice"
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

local function drawTallyGroup(resultType, count, x, y, rowHeight)
    if not count or count <= 0 then
        return x
    end

    local iconY = y + (rowHeight - TALLY_ICON_SIZE) / 2
    local text = tostring(count)
    local font = love.graphics.getFont()

    drawImageCentered(getTallyIcon(resultType), x, iconY, TALLY_ICON_SIZE)

    love.graphics.setColor(1, 1, 1)
    love.graphics.print(
        text,
        x + TALLY_ICON_SIZE + TALLY_TEXT_GAP,
        y + (rowHeight - font:getHeight()) / 2 + TALLY_ROW_TEXT_Y_OFFSET
    )

    return x + TALLY_ICON_SIZE + TALLY_TEXT_GAP + font:getWidth(text) + TALLY_GROUP_GAP
end

local function getTallyGroupWidth(resultType, count)
    if not count or count <= 0 then
        return 0
    end

    return TALLY_ICON_SIZE + TALLY_TEXT_GAP + love.graphics.getFont():getWidth(tostring(count))
end

local function getTallyRowGroups(tally, types, x, y, width, rowHeight)
    local totalWidth = 0
    local visibleGroups = 0
    local groupWidths = {}

    for _, resultType in ipairs(types) do
        local groupWidth = getTallyGroupWidth(resultType, tally[resultType])
        groupWidths[resultType] = groupWidth

        if groupWidth > 0 then
            totalWidth = totalWidth + groupWidth
            visibleGroups = visibleGroups + 1
        end
    end

    if visibleGroups == 0 then
        return {}
    end

    totalWidth = totalWidth + math.max(0, visibleGroups - 1) * TALLY_GROUP_GAP

    local availableWidth = width - TALLY_ROW_PADDING_X * 2
    local groupX = x + TALLY_ROW_PADDING_X + math.max(0, (availableWidth - totalWidth) / 2)
    local groups = {}

    for _, resultType in ipairs(types) do
        local groupWidth = groupWidths[resultType]

        if groupWidth > 0 then
            groups[resultType] = {
                x = groupX,
                y = y,
                width = groupWidth,
                height = rowHeight,
                iconX = groupX,
                iconY = y + (rowHeight - TALLY_ICON_SIZE) / 2,
                iconCenterX = groupX + TALLY_ICON_SIZE / 2,
                iconCenterY = y + rowHeight / 2,
            }
            groupX = groupX + groupWidth + TALLY_GROUP_GAP
        end
    end

    return groups
end

local function drawTallyRow(tally, types, x, y, width, rowHeight)
    local groups = getTallyRowGroups(tally, types, x, y, width, rowHeight)

    for _, resultType in ipairs(types) do
        local group = groups[resultType]

        if group then
            drawTallyGroup(resultType, tally[resultType], group.x, y, rowHeight)
        end
    end
end

local function drawTallySlot(side, x, y, width, height)
    local tallies = combatLogic.getAttackRollTallies()
    local tally = tallies[side] or {}
    local rowHeight = height / 2

    if side == "hostile" then
        drawTallyRow(tally, { "damage", "tac", "ammo" }, x, y, width, rowHeight)
        drawTallyRow(tally, { "shield" }, x, y + rowHeight, width, rowHeight)
    else
        drawTallyRow(tally, { "shield" }, x, y, width, rowHeight)
        drawTallyRow(tally, { "damage", "tac", "ammo" }, x, y + rowHeight, width, rowHeight)
    end
end

local function getTallyIconCenter(side, resultType, x, y, width, height)
    local tallies = combatLogic.getAttackRollTallies()
    local tally = tallies[side] or {}
    local rowHeight = height / 2
    local groups

    if side == "hostile" then
        if resultType == "shield" then
            groups = getTallyRowGroups(tally, { "shield" }, x, y + rowHeight, width, rowHeight)
        else
            groups = getTallyRowGroups(tally, { "damage", "tac", "ammo" }, x, y, width, rowHeight)
        end
    elseif resultType == "shield" then
        groups = getTallyRowGroups(tally, { "shield" }, x, y, width, rowHeight)
    else
        groups = getTallyRowGroups(tally, { "damage", "tac", "ammo" }, x, y + rowHeight, width, rowHeight)
    end

    local group = groups[resultType]

    if not group then
        return nil
    end

    return group.iconCenterX, group.iconCenterY
end

local function drawFaceResult(face, x, y, alpha)
    if not face then
        return
    end

    alpha = alpha or 1

    local text

    if face.value and face.value > 1 then
        text = tostring(face.value)
    end

    if face.htype then
        drawResultIcon(face.type, x - 4, y - 4, RESULT_ICON_SIZE, 0.95 * alpha)
        drawResultIcon(face.htype, x + 4, y + 4, RESULT_ICON_SIZE, 0.95 * alpha)
    else
        drawResultIcon(face.type, x, y, RESULT_ICON_SIZE, alpha)
    end

    if text then
        love.graphics.setColor(1, 1, 1, alpha)
        love.graphics.print(text, x + RESULT_ICON_SIZE - 6, y + RESULT_ICON_SIZE - 13, 0, 0.65, 0.65)
    end
end

local function drawAttackRollReveal()
    local currentRoll = combatLogic.getCurrentAttackRoll()

    if not currentRoll then
        return
    end

    local screenHeight = love.graphics.getHeight()
    local imageX = RESULT_REVEAL_MARGIN
    local imageY = RESULT_REVEAL_MARGIN

    if currentRoll.side == "player" then
        imageY = screenHeight - RESULT_REVEAL_MARGIN - RESULT_REVEAL_IMAGE_SIZE
    end

    local panelX = imageX + RESULT_REVEAL_IMAGE_SIZE + RESULT_REVEAL_PANEL_GAP
    local panelY = imageY
    local panelHeight = RESULT_REVEAL_IMAGE_SIZE
    local label = ("%s x%d"):format(currentRoll.unitId, currentRoll.count)

    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle("fill", imageX, imageY, RESULT_REVEAL_IMAGE_SIZE, RESULT_REVEAL_IMAGE_SIZE)

    love.graphics.setColor(1, 1, 1)
    love.graphics.setLineWidth(SLOT_OUTLINE_WIDTH)
    love.graphics.rectangle("line", imageX, imageY, RESULT_REVEAL_IMAGE_SIZE, RESULT_REVEAL_IMAGE_SIZE)
    unitRndr.drawCombatUnit(currentRoll.unitId, imageX, imageY, RESULT_REVEAL_IMAGE_SIZE)

    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle("fill", panelX, panelY, RESULT_REVEAL_PANEL_WIDTH, panelHeight)

    love.graphics.setColor(1, 1, 1)
    love.graphics.setLineWidth(SLOT_OUTLINE_WIDTH)
    love.graphics.rectangle("line", panelX, panelY, RESULT_REVEAL_PANEL_WIDTH, panelHeight)
    love.graphics.print(label, panelX + RESULT_REVEAL_PANEL_PADDING, panelY + 8, 0, 0.7, 0.7)

    local startX = panelX + RESULT_REVEAL_PANEL_PADDING
    local startY = panelY + 38
    local maxRows = math.max(1, math.floor((panelHeight - 48) / (RESULT_ICON_SIZE + RESULT_ICON_GAP)))
    local maxIcons = RESULT_ICON_COLUMNS * maxRows

    for index, face in ipairs(currentRoll.results or {}) do
        if index > maxIcons then
            love.graphics.setColor(1, 1, 1)
            love.graphics.print(
                ("+%d"):format(#currentRoll.results - maxIcons),
                startX + (RESULT_ICON_COLUMNS - 1) * (RESULT_ICON_SIZE + RESULT_ICON_GAP),
                startY + (maxRows - 1) * (RESULT_ICON_SIZE + RESULT_ICON_GAP)
            )
            break
        end

        local column = (index - 1) % RESULT_ICON_COLUMNS
        local row = math.floor((index - 1) / RESULT_ICON_COLUMNS)
        local elapsed = love.timer.getTime() - (currentRoll.revealedAt or 0) - (index - 1) * RESULT_ICON_ANIM_STAGGER
        local progress = clamp(elapsed / RESULT_ICON_ANIM_DURATION, 0, 1)
        local easedProgress = easeOutBack(progress)
        local alpha = progress
        local yOffset = (1 - easedProgress) * -RESULT_ICON_ANIM_DROP

        drawFaceResult(
            face,
            startX + column * (RESULT_ICON_SIZE + RESULT_ICON_GAP),
            startY + row * (RESULT_ICON_SIZE + RESULT_ICON_GAP) + yOffset,
            alpha
        )
    end
end

local function getTallySlotBounds(side, layout, hostileTallyY, playerTallyY)
    if side == "hostile" then
        return layout.x, hostileTallyY, layout.slotWidth, layout.smallSlotHeight
    end

    return layout.x, playerTallyY, layout.slotWidth, layout.smallSlotHeight
end

local function drawFireDamageJitter(layout, hostileTallyY, playerTallyY)
    local resolution = combatLogic.getFireDamageResolution()

    if not resolution.active then
        return
    end

    local now = love.timer.getTime()

    for _, step in ipairs(resolution.steps or {}) do
        local rawProgress = (now - step.startTime) / step.duration

        if rawProgress >= 0 and rawProgress < FIRE_DAMAGE_PUNCH_IMPACT then
            local sourceX, sourceY, sourceWidth, sourceHeight = getTallySlotBounds(step.attackerSide, layout, hostileTallyY, playerTallyY)
            local targetX, targetY, targetWidth, targetHeight = getTallySlotBounds(step.defenderSide, layout, hostileTallyY, playerTallyY)
            local startX, startY = getTallyIconCenter(step.attackerSide, "damage", sourceX, sourceY, sourceWidth, sourceHeight)
            local endX, endY = getTallyIconCenter(step.defenderSide, "shield", targetX, targetY, targetWidth, targetHeight)

            if startX and endX then
                local progress = clamp(rawProgress / FIRE_DAMAGE_PUNCH_IMPACT, 0, 1)
                local envelope = math.sin(progress * math.pi)
                local jitter = math.sin(now * FIRE_DAMAGE_JITTER_SPEED) * FIRE_DAMAGE_JITTER_AMPLITUDE * envelope

                drawImageCentered(getTallyIcon("damage"), startX - TALLY_ICON_SIZE / 2 + jitter, startY - TALLY_ICON_SIZE / 2, TALLY_ICON_SIZE)
                drawImageCentered(getTallyIcon("shield"), endX - TALLY_ICON_SIZE / 2 - jitter, endY - TALLY_ICON_SIZE / 2, TALLY_ICON_SIZE)
            end
        end
    end
end

local function drawEliminationPromptLabel(text, x, y, width)
    local font = love.graphics.getFont()
    local textWidth = font:getWidth(text)
    local textHeight = font:getHeight()
    local promptWidth = math.min(width, textWidth + ELIMINATION_PROMPT_PADDING * 2)
    local promptX = x + (width - promptWidth) / 2

    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle("fill", promptX, y, promptWidth, ELIMINATION_PROMPT_HEIGHT)

    love.graphics.setColor(1, 1, 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", promptX, y, promptWidth, ELIMINATION_PROMPT_HEIGHT)
    love.graphics.print(
        text,
        promptX + (promptWidth - textWidth) / 2,
        y + (ELIMINATION_PROMPT_HEIGHT - textHeight) / 2 + ELIMINATION_PROMPT_TEXT_Y_OFFSET
    )
end

local function drawFireDamageEliminationPrompts(layout, hostileY, playerY)
    if not combatLogic.isFireDamageEliminationActive() then
        return
    end

    local assignmentCounts = combatLogic.getFireDamageAssignmentCounts()

    if assignmentCounts.hostile > 0 then
        drawEliminationPromptLabel(
            ("ELIMINATE %d HOSTILE"):format(assignmentCounts.hostile),
            layout.x,
            hostileY - ELIMINATION_PROMPT_GAP - ELIMINATION_PROMPT_HEIGHT,
            layout.slotWidth
        )
    end

    if assignmentCounts.player > 0 then
        drawEliminationPromptLabel(
            ("ELIMINATE %d PLAYER"):format(assignmentCounts.player),
            layout.x,
            playerY + layout.slotHeight + ELIMINATION_PROMPT_GAP,
            layout.slotWidth
        )
    end
end

local function getEliminatingUnitKeys()
    local hiddenUnitKeys = {}

    for _, anim in ipairs(eliminationAnims) do
        if anim.unitKey then
            hiddenUnitKeys[anim.unitKey] = true
        end
    end

    return hiddenUnitKeys
end

local function addEliminationAnim(side, unitId, unitKey, bounds)
    if not unitId or not bounds then
        return
    end

    table.insert(eliminationAnims, {
        side = side,
        unitId = unitId,
        unitKey = unitKey,
        x = bounds.x,
        y = bounds.y,
        size = bounds.size,
        startedAt = love.timer.getTime(),
    })
end

local function drawEliminationAnims()
    local now = love.timer.getTime()

    for index = #eliminationAnims, 1, -1 do
        local anim = eliminationAnims[index]
        local progress = clamp((now - anim.startedAt) / ELIMINATION_ANIM_DURATION, 0, 1)

        if progress >= 1 then
            combatLogic.finalizeUnitElimination(anim.side, anim.unitId)
            table.remove(eliminationAnims, index)
        else
            local wipeX = anim.x + anim.size * progress
            local remainingWidth = anim.size - anim.size * progress
            local alpha = 1 - progress * ELIMINATION_WIPE_FADE

            love.graphics.stencil(function()
                love.graphics.rectangle("fill", wipeX, anim.y, remainingWidth, anim.size)
            end, "replace", 1)
            love.graphics.setStencilTest("greater", 0)

            unitRndr.drawCombatUnit(anim.unitId, anim.x, anim.y, anim.size, {
                alpha = alpha,
            })

            love.graphics.setStencilTest()
        end
    end
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

    local hiddenUnitKeys = getEliminatingUnitKeys()

    drawPhaseTracker(layout.phaseX, layout.y, layout.rowStackHeight)
    drawSlot("hostile", layout.x, hostileY, layout.slotWidth, layout.slotHeight, {
        hiddenUnitKeys = hiddenUnitKeys,
    })
    drawSlotFrame(layout.x, firstSmallSlotY, layout.slotWidth, layout.smallSlotHeight)
    drawTallySlot("hostile", layout.x, firstSmallSlotY, layout.slotWidth, layout.smallSlotHeight)
    drawSlotFrame(layout.x, secondSmallSlotY, layout.slotWidth, layout.smallSlotHeight)
    drawTallySlot("player", layout.x, secondSmallSlotY, layout.slotWidth, layout.smallSlotHeight)
    drawSlot("player", layout.x, playerY, layout.slotWidth, layout.slotHeight, {
        hiddenUnitKeys = hiddenUnitKeys,
    })

    if combatLogic.isAttackPhase() and not combatLogic.isShowingAttackRoll() then
        drawCombatDiceButton(layout, playerY)
    end

    drawAttackRollReveal()
    drawFireDamageJitter(layout, firstSmallSlotY, secondSmallSlotY)
    drawFireDamageEliminationPrompts(layout, hostileY, playerY)
    drawEliminationAnims()

    love.graphics.setColor(1, 1, 1)
end

local function getCombatSlotY(side, layout)
    if side == "hostile" then
        return layout.y
    end

    return layout.y + layout.slotHeight + layout.gap * 3 + layout.smallSlotHeight * 2
end

local function handleFireDamageEliminationClickForSide(side, layout, hiddenUnitKeys, pointX, pointY)
    if not combatLogic.canAssignDamageToSide(side) then
        return false
    end

    local slotY = getCombatSlotY(side, layout)
    local unitId, _, unitKey, bounds = unitRndr.getUnitAtSlot(
        side,
        layout.x,
        slotY,
        layout.slotWidth,
        layout.slotHeight,
        getSlotScrollKey(side),
        pointX,
        pointY,
        {
            hiddenUnitKeys = hiddenUnitKeys,
        }
    )

    if not unitId then
        return false
    end

    if combatLogic.assignDamageToUnit(side, unitId) then
        addEliminationAnim(side, unitId, unitKey, bounds)
        return true
    end

    return false
end

function cutRndr.handleFireDamageEliminationClick(pointX, pointY)
    if cutRndr.isFireDamageEliminationAnimating() then
        return false
    end

    if not combatLogic.isFireDamageEliminationActive() then
        return false
    end

    local layout = getCutInLayout()
    local hiddenUnitKeys = getEliminatingUnitKeys()

    if handleFireDamageEliminationClickForSide("hostile", layout, hiddenUnitKeys, pointX, pointY) then
        return true
    elseif handleFireDamageEliminationClickForSide("player", layout, hiddenUnitKeys, pointX, pointY) then
        return true
    end

    return false
end

function cutRndr.isFireDamageEliminationAnimating()
    return #eliminationAnims > 0
end

function cutRndr.isCursorOverCombatDiceButton(pointX, pointY)
    if not combatLogic.isCutInActive()
        or not combatLogic.isAttackPhase()
        or combatLogic.isShowingAttackRoll() then
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
