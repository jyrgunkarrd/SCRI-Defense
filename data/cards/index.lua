local cardIndex = {
    categorized = {},
    byId = {},
    all = {},
}

local ROOT_PATH = "data/cards"
local unpack = table.unpack or unpack

local function pathToModule(path)
    local module = path:gsub("%.lua$", ""):gsub("/", ".")
    return module
end

local function addCards(categoryPath, moduleName)
    local cards = require(moduleName)
    local category = cardIndex.categorized

    for _, segment in ipairs(categoryPath) do
        category[segment] = category[segment] or {}
        category = category[segment]
    end

    for _, card in ipairs(cards) do
        category[card.id] = card
        cardIndex.byId[card.id] = card
        table.insert(cardIndex.all, card)
    end
end

local function scanDirectory(path, categoryPath)
    local items = love.filesystem.getDirectoryItems(path)
    table.sort(items)

    for _, item in ipairs(items) do
        local itemPath = ("%s/%s"):format(path, item)
        local info = love.filesystem.getInfo(itemPath)

        if info and info.type == "directory" then
            local nextCategoryPath = { unpack(categoryPath) }
            table.insert(nextCategoryPath, item)
            scanDirectory(itemPath, nextCategoryPath)
        elseif info and info.type == "file" and item:match("%.lua$") and item ~= "index.lua" then
            addCards(categoryPath, pathToModule(itemPath))
        end
    end
end

scanDirectory(ROOT_PATH, {})

return cardIndex
