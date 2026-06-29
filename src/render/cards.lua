local cards = {}
local imageLoader = require("src.assets.image_loader")
local handsDecks = require("src.system.hands_decks")
local sfx = require("src.audio.sfx")

local CARD_ID = "AIRSUP"
local HAND_CARD_SPACING = 220
local HAND_EDGE_MARGIN = 48
local CARD_BACKING_PADDING = 10
local HOVER_PREVIEW_HAND_GAP = 18
local HOVER_PREVIEW_TOP_MARGIN = 18
local CARD_WIDTH = 360
local CARD_RADIUS = 14
local CARD_PADDING = 16
local CARD_OUTLINE_WIDTH = 2
local HEADER_HEIGHT = 52
local TEXT_BOX_HEIGHT = 244
local FALLBACK_IMAGE_HEIGHT = 244
local TEXT_BOX_PADDING = 18
local BODY_FONT_SIZE = 14
local FLAVOR_FONT_SIZE = 13
local TEXT_BLOCK_GAP = 12
local COST_PIP_WIDTH = 7
local COST_PIP_GAP = 5
local COST_PIP_TEXT_GAP = 6
local COST_PIP_BOTTOM_INSET = 2
local COST_BOX_GAP = 12
local ZERO_COST_PIP_WIDTH = 24
local ZERO_COST_PIP_HEIGHT = 6
local ZERO_COST_PIP_TOP_PADDING = 12
local HEADER_TEXT_Y_OFFSET = 2
local SPEED_LABEL_WIDTH = 96
local SPEED_LABEL_HEIGHT = 34
local SPEED_LABEL_TEXT_Y_OFFSET = -2
local METHOD_ICON_SIZE = 32
local METHOD_PANEL_PADDING = 8
local METHOD_ICON_GAP = 6
local METHOD_PANEL_COLUMNS = 1
local METHOD_PANEL_ROWS = 8
local CARD_IMAGE_EXTENSIONS = { "webp", "png", "jpg", "jpeg" }
local METHOD_ICON_EXTENSIONS = { "png", "webp", "jpg", "jpeg" }
local SPEED_COLORS = {
    fast = { 0.792, 0, 0.227 },
    quick = { 0.792, 0, 0.227 },
    steady = { 0, 0.416, 0.525 },
}

local cardDefinition
local cardIndex
local cardImages = {}
local bodyFont
local flavorFont
local methodIcons = {}
local hoveredHandCardIndex

local function getSpeedColor(speed)
    return SPEED_COLORS[(speed or ""):lower()] or { 1, 1, 1 }
end

local function getSpeedLabel(speed)
    local normalizedSpeed = (speed or ""):lower()

    if normalizedSpeed == "fast" then
        return "quick"
    end

    return normalizedSpeed
end

local function findCardImagePath(cardId)
    for _, extension in ipairs(CARD_IMAGE_EXTENSIONS) do
        local path = ("assets/images/cards/%s.%s"):format(cardId, extension)

        if love.filesystem.getInfo(path, "file") then
            return path
        end
    end
end

local function findMethodIconPath(method)
    for _, extension in ipairs(METHOD_ICON_EXTENSIONS) do
        local path = ("assets/images/icons/methods/%s.%s"):format(method, extension)

        if love.filesystem.getInfo(path, "file") then
            return path
        end
    end
end

local function loadCardAssets(card)
    if not card then
        return
    end

    if not cardImages[card.id] then
        local imagePath = findCardImagePath(card.id)

        if imagePath then
            cardImages[card.id] = imageLoader.newImage(imagePath)
        end
    end

    for _, method in ipairs(card.methods or {}) do
        if not methodIcons[method] then
            local iconPath = findMethodIconPath(method)

            if iconPath then
                methodIcons[method] = imageLoader.newImage(iconPath)
            end
        end
    end
end

function cards.load()
    cardIndex = require("data.cards.index")
    cardDefinition = cardIndex.byId[CARD_ID]
    bodyFont = love.graphics.newFont("assets/fonts/Furore.otf", BODY_FONT_SIZE)
    flavorFont = love.graphics.newFont("assets/fonts/DejaVuSans-Oblique.ttf", FLAVOR_FONT_SIZE)

    if love.math and love.math.setRandomSeed then
        love.math.setRandomSeed(os.time())
    end

    loadCardAssets(cardDefinition)
    handsDecks.buildPlayerHand(cardIndex)

    for _, card in ipairs(handsDecks.getPlayerHand()) do
        loadCardAssets(card)
    end
end

local function getCardImageHeight(card)
    local cardImage = card and cardImages[card.id] or nil

    if not cardImage then
        return FALLBACK_IMAGE_HEIGHT
    end

    return CARD_WIDTH * cardImage:getHeight() / cardImage:getWidth()
end

local function drawCardImage(card, x, y, width)
    local cardImage = card and cardImages[card.id] or nil

    if not cardImage then
        return
    end

    local scale = width / cardImage:getWidth()
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(cardImage, x, y, 0, scale, scale)
end

local function drawWrappedText(text, x, y, width, height, align, font, verticalAlign)
    local previousFont = love.graphics.getFont()
    font = font or previousFont
    love.graphics.setFont(font)

    local _, wrappedLines = font:getWrap(text, width)
    local textHeight = #wrappedLines * font:getHeight()
    local textY = y

    if verticalAlign ~= "top" then
        textY = y + (height - textHeight) / 2
    end

    love.graphics.printf(text, x, textY, width, align)
    love.graphics.setFont(previousFont)

    return textY, textHeight
end

local function drawTextBoxContent(text, flavor, x, y, width, height)
    local _, textHeight = drawWrappedText(text, x, y, width, height, "left", bodyFont, "top")

    if not flavor or flavor == "" then
        return
    end

    local flavorY = y + textHeight + TEXT_BLOCK_GAP
    local remainingHeight = height - textHeight - TEXT_BLOCK_GAP

    if remainingHeight > 0 then
        drawWrappedText(flavor, x, flavorY, width, remainingHeight, "left", flavorFont, "top")
    end
end

local function getWrappedTextBounds(text, x, y, width, height, font, verticalAlign)
    font = font or love.graphics.getFont()

    local _, wrappedLines = font:getWrap(text, width)
    local textHeight = #wrappedLines * font:getHeight()
    local textY = y

    if verticalAlign ~= "top" then
        textY = y + (height - textHeight) / 2
    end

    return x, textY, width, textHeight
end

local function drawCostPips(cost, x, y, bottomY, color)
    local pipCount = math.max(0, math.floor(cost or 0))
    local pipHeight = bottomY - y - COST_PIP_BOTTOM_INSET

    if pipHeight <= 0 then
        return
    end

    love.graphics.setColor(color)

    if pipCount == 0 then
        local pipY = y + ZERO_COST_PIP_TOP_PADDING
        love.graphics.rectangle("fill", x, pipY, ZERO_COST_PIP_WIDTH, ZERO_COST_PIP_HEIGHT)

        return x + ZERO_COST_PIP_WIDTH, y + pipHeight
    end

    for index = 1, pipCount do
        local pipX = x + (index - 1) * (COST_PIP_WIDTH + COST_PIP_GAP)
        love.graphics.rectangle("fill", pipX, y, COST_PIP_WIDTH, pipHeight)
    end

    return x + pipCount * COST_PIP_WIDTH + (pipCount - 1) * COST_PIP_GAP, y + pipHeight
end

local function drawClippedHeaderBox(cardX, cardY, cardHeight, boxX, boxBottomY, color)
    local boxWidth = cardX + CARD_WIDTH - boxX
    local boxHeight = boxBottomY - cardY

    if boxWidth <= 0 or boxHeight <= 0 then
        return
    end

    love.graphics.stencil(function()
        love.graphics.rectangle("fill", cardX, cardY, CARD_WIDTH, cardHeight, CARD_RADIUS, CARD_RADIUS)
    end, "replace", 1)
    love.graphics.setStencilTest("greater", 0)

    love.graphics.setColor(color)
    love.graphics.rectangle("fill", boxX, cardY, boxWidth, boxHeight)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", boxX, cardY, boxWidth, boxHeight)

    love.graphics.setStencilTest()
end

local function drawSpeedLabel(speed, x, y, color)
    local label = getSpeedLabel(speed)

    love.graphics.setColor(color)
    love.graphics.rectangle("fill", x, y, SPEED_LABEL_WIDTH, SPEED_LABEL_HEIGHT)

    love.graphics.setColor(0, 0, 0)
    love.graphics.setLineWidth(2)
    love.graphics.line(x, y + SPEED_LABEL_HEIGHT, x + SPEED_LABEL_WIDTH, y + SPEED_LABEL_HEIGHT)
    love.graphics.line(x + SPEED_LABEL_WIDTH, y, x + SPEED_LABEL_WIDTH, y + SPEED_LABEL_HEIGHT)

    love.graphics.setColor(1, 1, 1)
    drawWrappedText(label, x, y + SPEED_LABEL_TEXT_Y_OFFSET, SPEED_LABEL_WIDTH, SPEED_LABEL_HEIGHT, "center")
end

local function getVisibleMethods(methods)
    local visibleMethods = {}

    for index, method in ipairs(methods or {}) do
        if index > METHOD_PANEL_COLUMNS * METHOD_PANEL_ROWS then
            break
        end

        table.insert(visibleMethods, method)
    end

    return visibleMethods
end

local function drawMethodIcon(icon, x, y)
    if not icon then
        return
    end

    local scale = math.min(METHOD_ICON_SIZE / icon:getWidth(), METHOD_ICON_SIZE / icon:getHeight())
    local width = icon:getWidth() * scale
    local height = icon:getHeight() * scale
    local iconX = x + (METHOD_ICON_SIZE - width) / 2
    local iconY = y + (METHOD_ICON_SIZE - height) / 2

    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(icon, iconX, iconY, 0, scale, scale)
end

local function drawMethodPanel(methods, x, y)
    local visibleMethods = getVisibleMethods(methods)
    local iconCount = #visibleMethods

    if iconCount == 0 then
        return
    end

    local columns = math.min(iconCount, METHOD_PANEL_COLUMNS)
    local rows = math.ceil(iconCount / METHOD_PANEL_COLUMNS)
    local panelWidth = METHOD_PANEL_PADDING * 2 + columns * METHOD_ICON_SIZE + (columns - 1) * METHOD_ICON_GAP
    local panelHeight = METHOD_PANEL_PADDING * 2 + rows * METHOD_ICON_SIZE + (rows - 1) * METHOD_ICON_GAP

    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle("fill", x, y, panelWidth, panelHeight)

    for index, method in ipairs(visibleMethods) do
        local column = (index - 1) % METHOD_PANEL_COLUMNS
        local row = math.floor((index - 1) / METHOD_PANEL_COLUMNS)
        local iconX = x + METHOD_PANEL_PADDING + column * (METHOD_ICON_SIZE + METHOD_ICON_GAP)
        local iconY = y + METHOD_PANEL_PADDING + row * (METHOD_ICON_SIZE + METHOD_ICON_GAP)

        drawMethodIcon(methodIcons[method], iconX, iconY)
    end
end

local function getCardHeight(card)
    return CARD_PADDING + HEADER_HEIGHT + getCardImageHeight(card) + CARD_PADDING + TEXT_BOX_HEIGHT + CARD_PADDING
end

local function getVisibleHandCardHeight()
    return CARD_PADDING + HEADER_HEIGHT + SPEED_LABEL_HEIGHT
end

local function getExtendedHandCardHeight(card)
    return CARD_PADDING + HEADER_HEIGHT + getCardImageHeight(card)
end

local function getPlayerHandLayout()
    local handCards = handsDecks.getPlayerHand()
    local cardCount = #handCards

    if cardCount == 0 then
        return nil
    end

    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    local availableWidth = screenWidth - HAND_EDGE_MARGIN * 2
    local spacing = HAND_CARD_SPACING

    local handFaceWidth = CARD_WIDTH + spacing * (cardCount - 1)
    local handOuterWidth = handFaceWidth + CARD_BACKING_PADDING * 2
    local maxScroll = math.max(0, handOuterWidth - availableWidth)
    local scroll = math.max(0, math.min(handsDecks.getPlayerHandScroll(), maxScroll))
    local startX = (screenWidth - handOuterWidth) / 2 + CARD_BACKING_PADDING

    if maxScroll > 0 then
        handsDecks.setPlayerHandScroll(scroll)
        startX = HAND_EDGE_MARGIN + CARD_BACKING_PADDING - scroll
    elseif handsDecks.getPlayerHandScroll() ~= 0 then
        handsDecks.setPlayerHandScroll(0)
    end
    local visibleHeight = getVisibleHandCardHeight()

    if handsDecks.isPlayerHandExtended() then
        visibleHeight = getExtendedHandCardHeight(handCards[1])
    end

    return {
        cards = handCards,
        count = cardCount,
        startX = startX,
        spacing = spacing,
        y = screenHeight - visibleHeight,
    }
end

local function getHoveredHandCard(layout)
    if not layout then
        return nil
    end

    local mouseX, mouseY = love.mouse.getPosition()

    for index = layout.count, 1, -1 do
        local card = layout.cards[index]
        local x = layout.startX + (index - 1) * layout.spacing
        local cardHeight = getCardHeight(card)

        if mouseX >= x and mouseX <= x + CARD_WIDTH and mouseY >= layout.y and mouseY <= layout.y + cardHeight then
            return card, index
        end
    end
end

local function drawCard(card, x, y)
    if not card then
        return
    end

    local imageHeight = getCardImageHeight(card)
    local cardHeight = getCardHeight(card)
    local contentX = x + CARD_PADDING
    local contentY = y + CARD_PADDING
    local contentWidth = CARD_WIDTH - CARD_PADDING * 2
    local headerY = contentY
    local imageY = headerY + HEADER_HEIGHT
    local textBoxY = imageY + imageHeight + CARD_PADDING
    local speedColor = getSpeedColor(card.speed)

    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle(
        "fill",
        x - CARD_BACKING_PADDING,
        y - CARD_BACKING_PADDING,
        CARD_WIDTH + CARD_BACKING_PADDING * 2,
        cardHeight + CARD_BACKING_PADDING * 2,
        CARD_RADIUS + CARD_BACKING_PADDING,
        CARD_RADIUS + CARD_BACKING_PADDING
    )

    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle("fill", x, y, CARD_WIDTH, cardHeight, CARD_RADIUS, CARD_RADIUS)

    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle("fill", contentX, headerY, contentWidth, HEADER_HEIGHT)

    local _, headerTextY = getWrappedTextBounds(card.name, contentX, headerY, contentWidth, HEADER_HEIGHT)
    local pipsRightX, pipsBottomY = drawCostPips(card.cost, contentX, y, headerTextY - COST_PIP_TEXT_GAP, speedColor)
    if pipsRightX and pipsBottomY then
        drawClippedHeaderBox(x, y, cardHeight, pipsRightX + COST_BOX_GAP, pipsBottomY, speedColor)
    end

    love.graphics.setColor(1, 1, 1)
    drawWrappedText(card.name, contentX, headerY + HEADER_TEXT_Y_OFFSET, contentWidth, HEADER_HEIGHT, "left")

    drawCardImage(card, x, imageY, CARD_WIDTH)
    drawSpeedLabel(card.speed, x, imageY, speedColor)
    drawMethodPanel(card.methods, x, imageY + SPEED_LABEL_HEIGHT)

    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle("fill", contentX, textBoxY, contentWidth, TEXT_BOX_HEIGHT)

    love.graphics.setColor(speedColor)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", contentX, textBoxY, contentWidth, TEXT_BOX_HEIGHT)
    love.graphics.setColor(1, 1, 1)
    drawTextBoxContent(card.textbox or "", card.flavor, contentX + TEXT_BOX_PADDING, textBoxY + TEXT_BOX_PADDING, contentWidth - TEXT_BOX_PADDING * 2, TEXT_BOX_HEIGHT - TEXT_BOX_PADDING * 2)

    love.graphics.setColor(speedColor)
    love.graphics.setLineWidth(CARD_OUTLINE_WIDTH)
    love.graphics.rectangle("line", x, y, CARD_WIDTH, cardHeight, CARD_RADIUS, CARD_RADIUS)

    love.graphics.setColor(1, 1, 1)
end

local function drawScaledCard(card, x, y, scale)
    love.graphics.push()
    love.graphics.translate(x, y)
    love.graphics.scale(scale, scale)
    drawCard(card, 0, 0)
    love.graphics.pop()
end

function cards.drawFocusedCard()
    local layout = getPlayerHandLayout()
    local hoveredCard, hoveredIndex = getHoveredHandCard(layout)

    if hoveredIndex ~= hoveredHandCardIndex then
        hoveredHandCardIndex = hoveredIndex

        if hoveredIndex then
            sfx.play("cardhover")
        end
    end

    if not hoveredCard then
        return
    end

    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    local cardHeight = getCardHeight(hoveredCard)
    local scale = 1
    local x = (screenWidth - CARD_WIDTH) / 2
    local y = (screenHeight - cardHeight) / 2

    if handsDecks.isPlayerHandExtended() then
        local previewOuterHeight = cardHeight + CARD_BACKING_PADDING * 2
        local availableHeight = layout.y - HOVER_PREVIEW_HAND_GAP - HOVER_PREVIEW_TOP_MARGIN

        if availableHeight > 0 then
            scale = math.min(1, availableHeight / previewOuterHeight)
        end

        local previewOuterTop = layout.y - HOVER_PREVIEW_HAND_GAP - previewOuterHeight * scale
        previewOuterTop = math.max(HOVER_PREVIEW_TOP_MARGIN, previewOuterTop)
        x = (screenWidth - CARD_WIDTH * scale) / 2
        y = previewOuterTop + CARD_BACKING_PADDING * scale
    end

    drawScaledCard(hoveredCard, x, y, scale)
end

function cards.drawPlayerHand()
    local layout = getPlayerHandLayout()

    if not layout then
        return
    end

    for index, card in ipairs(layout.cards) do
        drawCard(card, layout.startX + (index - 1) * layout.spacing, layout.y)
    end
end

return cards
