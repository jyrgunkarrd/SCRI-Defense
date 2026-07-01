local combatLogic = {}
local locationFacGeo = require("src.system.location_fac_geo")

local cutIn = {
    active = false,
    locationIndex = nil,
    selectedPhase = "fire_attack",
}

function combatLogic.startCutIn()
    cutIn.active = true
    cutIn.locationIndex = locationFacGeo.getSelectedLocationIndex()
    cutIn.selectedPhase = "fire_attack"
end

function combatLogic.dismissCutIn()
    cutIn.active = false
end

function combatLogic.isCutInActive()
    return cutIn.active
end

function combatLogic.getCutInLocationIndex()
    return cutIn.locationIndex
end

function combatLogic.getSelectedPhase()
    return cutIn.selectedPhase
end

return combatLogic
