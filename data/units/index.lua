local unitIndex = {
    categorized = {},
    byId = {},
    all = {},
}

local ROOT_PATH = "data/units"
local unpack = table.unpack or unpack

local function pathToModule(path)
    return path:gsub("%.lua$", ""):gsub("/", ".")
end

local function addUnits(categoryPath, moduleName)
    local units = require(moduleName)
    local category = unitIndex.categorized

    for _, segment in ipairs(categoryPath) do
        category[segment] = category[segment] or {}
        category = category[segment]
    end

    for _, unit in ipairs(units) do
        category[unit.id] = unit
        unitIndex.byId[unit.id] = unit
        table.insert(unitIndex.all, unit)
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
            addUnits(categoryPath, pathToModule(itemPath))
        end
    end
end

scanDirectory(ROOT_PATH, {})

return unitIndex
