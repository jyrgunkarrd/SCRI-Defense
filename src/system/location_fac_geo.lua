local facilityDefinitions = require("data.facility")

local locationFacGeo = {}

local LOCATION_COUNT = 10
local selectedLocationIndex = 1
local locations = {}

local function findFacilityById(facilityId)
    for _, facility in ipairs(facilityDefinitions) do
        if facility.id == facilityId then
            return facility
        end
    end
end

for index = 1, LOCATION_COUNT do
    locations[index] = {
        label = ("Location %d"):format(index),
    }
end

locations[1].facility = findFacilityById("VEC")

function locationFacGeo.getLocations()
    return locations
end

function locationFacGeo.getSelectedLocationIndex()
    return selectedLocationIndex
end

function locationFacGeo.selectLocation(index)
    if locations[index] then
        selectedLocationIndex = index
    end
end

function locationFacGeo.getSelectedLocation()
    return locations[selectedLocationIndex]
end

function locationFacGeo.getSelectedFacility()
    local location = locationFacGeo.getSelectedLocation()
    return location and location.facility or nil
end

function locationFacGeo.getLocationLabel(index)
    local location = locations[index]
    if not location then
        return ""
    end

    if location.facility then
        return location.facility.name
    end

    return location.label
end

return locationFacGeo
