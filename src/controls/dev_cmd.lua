local devCmd = {}
local combatLogic = require("src.system.combat_logic")

function devCmd.keypressed(key)
    if key == "f" then
        combatLogic.startCutIn()
        return true
    end

    return false
end

return devCmd
