local sfx = {}

local SFX_PATH = "assets/audio/sfx"
local SFX_EXTENSIONS = { "wav", "ogg", "mp3" }

local sources = {}

local function findSfxPath(name)
    for _, extension in ipairs(SFX_EXTENSIONS) do
        local path = ("%s/%s.%s"):format(SFX_PATH, name, extension)

        if love.filesystem.getInfo(path, "file") then
            return path
        end
    end
end

function sfx.load(name)
    if sources[name] then
        return sources[name]
    end

    local path = findSfxPath(name)
    if not path then
        return nil
    end

    sources[name] = love.audio.newSource(path, "static")
    return sources[name]
end

function sfx.play(name)
    local source = sfx.load(name)

    if not source then
        return
    end

    source:stop()
    source:play()
end

return sfx
