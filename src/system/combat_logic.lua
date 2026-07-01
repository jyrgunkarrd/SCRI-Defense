local combatLogic = {}
local locationFacGeo = require("src.system.location_fac_geo")
local sfx = require("src.audio.sfx")
local unitIndex = require("data.units.index")
local unitTesting = require("data.unittesting")

local diceIndex = {}

for _, die in ipairs(require("data.dice")) do
    diceIndex[die.id] = die
end

local ROW_FIELDS = {
    hostile = "hostileunits",
    player = "playerunits",
}
local FIRE_ATTACK_RATK = {
    skirm = true,
    snipe = true,
}
local DAMAGE_PHASE_BY_ATTACK_PHASE = {
    fire_attack = "fire_damage",
    steel_attack = "steel_damage",
}
local NEXT_PHASE_BY_DAMAGE_PHASE = {
    fire_damage = "steel_attack",
}
local FIRE_DAMAGE_PUNCH_DURATION = 0.42
local FIRE_DAMAGE_PUNCH_IMPACT = 0.72
local FIRE_DAMAGE_PUNCH_GAP = 0.12

local cutIn = {
    active = false,
    locationIndex = nil,
    selectedPhase = "fire_attack",
    attackRoll = {
        active = false,
        queue = {},
        currentIndex = 0,
        current = nil,
        tallies = {
            hostile = {},
            player = {},
        },
    },
    fireDamageResolution = {
        active = false,
        steps = {},
    },
    pendingEliminations = {
        hostile = {},
        player = {},
    },
}

local function resetAttackRoll()
    cutIn.attackRoll = {
        active = false,
        queue = {},
        currentIndex = 0,
        current = nil,
        tallies = {
            hostile = {},
            player = {},
        },
    }
    cutIn.fireDamageResolution = {
        active = false,
        steps = {},
    }
    cutIn.pendingEliminations = {
        hostile = {},
        player = {},
    }
end

local function isAttackPhase(phase)
    return DAMAGE_PHASE_BY_ATTACK_PHASE[phase] ~= nil
end

local function isDamagePhase(phase)
    return phase == "fire_damage" or phase == "steel_damage"
end

function combatLogic.startCutIn()
    cutIn.active = true
    cutIn.locationIndex = locationFacGeo.getSelectedLocationIndex()
    cutIn.selectedPhase = "fire_attack"
    resetAttackRoll()
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

function combatLogic.isAttackPhase()
    return isAttackPhase(cutIn.selectedPhase)
end

function combatLogic.isDamagePhase()
    return isDamagePhase(cutIn.selectedPhase)
end

local function getEntryCount(entry)
    return math.max(0, math.floor(entry.num == nil and 1 or entry.num))
end

local function getPendingEliminations(side, unitId)
    local sideEliminations = cutIn.pendingEliminations[side] or {}

    return sideEliminations[unitId] or 0
end

local function canUnitAttackInPhase(unit, phase)
    if phase == "fire_attack" then
        return FIRE_ATTACK_RATK[unit.ratk] == true
    elseif phase == "steel_attack" then
        return unit.ratk ~= "snipe"
    end

    return false
end

local function getStacksForSide(side)
    local selectedFacility = locationFacGeo.getSelectedFacility()
    local field = ROW_FIELDS[side]
    local stacks = {}

    if not selectedFacility or not field then
        return stacks
    end

    for _, entry in ipairs(unitTesting[field] or {}) do
        local unit = unitIndex.byId[entry.unit]
        local count = getEntryCount(entry)

        if entry.fac == selectedFacility.id and unit and canUnitAttackInPhase(unit, cutIn.selectedPhase) and count > 0 then
            table.insert(stacks, {
                side = side,
                unitId = entry.unit,
                count = count,
            })
        end
    end

    return stacks
end

local function getUnitCount(side)
    local selectedFacility = locationFacGeo.getSelectedFacility()
    local field = ROW_FIELDS[side]
    local count = 0

    if not selectedFacility or not field then
        return count
    end

    for _, entry in ipairs(unitTesting[field] or {}) do
        if entry.fac == selectedFacility.id and unitIndex.byId[entry.unit] then
            count = count + math.max(0, getEntryCount(entry) - getPendingEliminations(side, entry.unit))
        end
    end

    return count
end

local function buildAttackRollQueue()
    local playerStacks = getStacksForSide("player")
    local hostileStacks = getStacksForSide("hostile")
    local queue = {}
    local maxStacks = math.max(#playerStacks, #hostileStacks)

    for index = 1, maxStacks do
        if playerStacks[index] then
            table.insert(queue, playerStacks[index])
        end

        if hostileStacks[index] then
            table.insert(queue, hostileStacks[index])
        end
    end

    return queue
end

local function copyFace(face)
    local copiedFace = {}

    for key, value in pairs(face or {}) do
        copiedFace[key] = value
    end

    return copiedFace
end

local function recordResult(tally, resultType, value)
    if not resultType or resultType == "blank" then
        return
    end

    tally[resultType] = (tally[resultType] or 0) + math.max(1, math.floor(value or 1))
end

local function rollDie(dieId)
    local die = diceIndex[dieId]

    if not die then
        return nil
    end

    local faceIndex = love.math.random(1, 6)
    local face = copyFace(die.faces and die.faces[("F%d"):format(faceIndex)] or {})

    face.dieId = dieId
    face.faceIndex = faceIndex

    return face
end

local function rollStack(stack)
    local unit = unitIndex.byId[stack.unitId]
    local results = {}
    local tally = cutIn.attackRoll.tallies[stack.side]

    sfx.play("dice")

    for _ = 1, stack.count do
        for _, dieEntry in ipairs(unit.dice or {}) do
            for dieId, dieCount in pairs(dieEntry) do
                for _ = 1, math.max(1, math.floor(dieCount or 1)) do
                    local face = rollDie(dieId)

                    if face then
                        table.insert(results, face)
                        recordResult(tally, face.type, face.value)
                        recordResult(tally, face.htype, face.value)
                    end
                end
            end
        end
    end

    return {
        side = stack.side,
        unitId = stack.unitId,
        count = stack.count,
        results = results,
        revealedAt = love.timer.getTime(),
    }
end

local function spendShield(step)
    if step.applied then
        return
    end

    local tallies = cutIn.attackRoll.tallies
    local attackerTally = tallies[step.attackerSide] or {}
    local defenderTally = tallies[step.defenderSide] or {}

    attackerTally.damage = math.max(0, (attackerTally.damage or 0) - step.amount)
    defenderTally.shield = math.max(0, (defenderTally.shield or 0) - step.amount)
    step.applied = true
end

local function updateFireDamageResolution()
    local resolution = cutIn.fireDamageResolution

    if not resolution.active then
        return
    end

    local now = love.timer.getTime()
    local active = false

    for _, step in ipairs(resolution.steps) do
        if not step.soundPlayed and now >= step.startTime then
            sfx.play("damage")
            step.soundPlayed = true
        end

        if now >= step.startTime + FIRE_DAMAGE_PUNCH_DURATION * FIRE_DAMAGE_PUNCH_IMPACT then
            spendShield(step)
        end

        if now < step.startTime + FIRE_DAMAGE_PUNCH_DURATION then
            active = true
        end
    end

    resolution.active = active
end

local function beginDamageShieldSpend()
    local tallies = cutIn.attackRoll.tallies
    local playerTally = tallies.player or {}
    local hostileTally = tallies.hostile or {}
    local playerDamageBlocked = math.min(playerTally.damage or 0, hostileTally.shield or 0)
    local hostileDamageBlocked = math.min(hostileTally.damage or 0, playerTally.shield or 0)
    local startTime = love.timer.getTime()
    local steps = {}

    if playerDamageBlocked > 0 then
        table.insert(steps, {
            attackerSide = "player",
            defenderSide = "hostile",
            amount = playerDamageBlocked,
            startTime = startTime,
            duration = FIRE_DAMAGE_PUNCH_DURATION,
            applied = false,
            soundPlayed = false,
        })
    end

    if hostileDamageBlocked > 0 then
        table.insert(steps, {
            attackerSide = "hostile",
            defenderSide = "player",
            amount = hostileDamageBlocked,
            startTime = startTime + #steps * (FIRE_DAMAGE_PUNCH_DURATION + FIRE_DAMAGE_PUNCH_GAP),
            duration = FIRE_DAMAGE_PUNCH_DURATION,
            applied = false,
            soundPlayed = false,
        })
    end

    cutIn.fireDamageResolution = {
        active = #steps > 0,
        steps = steps,
    }
end

local function advanceAttackRoll()
    cutIn.attackRoll.currentIndex = cutIn.attackRoll.currentIndex + 1

    local stack = cutIn.attackRoll.queue[cutIn.attackRoll.currentIndex]

    if not stack then
        beginDamageShieldSpend()
        cutIn.attackRoll.current = nil
        cutIn.attackRoll.active = false
        cutIn.selectedPhase = DAMAGE_PHASE_BY_ATTACK_PHASE[cutIn.selectedPhase]
        return
    end

    cutIn.attackRoll.current = rollStack(stack)
end

function combatLogic.rollAttackDice()
    if not cutIn.active or not isAttackPhase(cutIn.selectedPhase) or cutIn.attackRoll.active then
        return false
    end

    cutIn.attackRoll.active = true
    cutIn.attackRoll.queue = buildAttackRollQueue()
    cutIn.attackRoll.currentIndex = 0
    cutIn.attackRoll.current = nil
    cutIn.attackRoll.tallies = {
        hostile = {},
        player = {},
    }

    advanceAttackRoll()
    return true
end

function combatLogic.advanceAttackRoll()
    if not cutIn.attackRoll.current then
        return false
    end

    advanceAttackRoll()
    return true
end

function combatLogic.isShowingAttackRoll()
    return cutIn.attackRoll.current ~= nil
end

function combatLogic.getCurrentAttackRoll()
    return cutIn.attackRoll.current
end

function combatLogic.getAttackRollTallies()
    updateFireDamageResolution()
    return cutIn.attackRoll.tallies
end

function combatLogic.getFireDamageResolution()
    updateFireDamageResolution()
    return cutIn.fireDamageResolution
end

function combatLogic.isFireDamageResolutionActive()
    updateFireDamageResolution()
    return cutIn.fireDamageResolution.active
end

function combatLogic.getRemainingPlayerDamage()
    updateFireDamageResolution()
    return cutIn.attackRoll.tallies.player.damage or 0
end

function combatLogic.getRemainingHostileDamage()
    updateFireDamageResolution()
    return cutIn.attackRoll.tallies.hostile.damage or 0
end

function combatLogic.isFireDamageEliminationActive()
    return isDamagePhase(cutIn.selectedPhase)
        and not combatLogic.isFireDamageResolutionActive()
        and (
            (combatLogic.getRemainingPlayerDamage() > 0 and getUnitCount("hostile") > 0)
            or (combatLogic.getRemainingHostileDamage() > 0 and getUnitCount("player") > 0)
        )
end

function combatLogic.getFireDamageAssignmentCounts()
    return {
        hostile = getUnitCount("hostile") > 0 and combatLogic.getRemainingPlayerDamage() or 0,
        player = getUnitCount("player") > 0 and combatLogic.getRemainingHostileDamage() or 0,
    }
end

local function getDamageSideForTarget(targetSide)
    if targetSide == "hostile" then
        return "player"
    elseif targetSide == "player" then
        return "hostile"
    end
end

function combatLogic.canAssignDamageToSide(targetSide)
    local damageSide = getDamageSideForTarget(targetSide)

    return damageSide ~= nil
        and isDamagePhase(cutIn.selectedPhase)
        and not combatLogic.isFireDamageResolutionActive()
        and (cutIn.attackRoll.tallies[damageSide].damage or 0) > 0
        and getUnitCount(targetSide) > 0
end

function combatLogic.assignDamageToUnit(targetSide, unitId)
    if not combatLogic.isFireDamageEliminationActive() then
        return false
    end

    local selectedFacility = locationFacGeo.getSelectedFacility()
    local field = ROW_FIELDS[targetSide]
    local damageSide = getDamageSideForTarget(targetSide)

    if not selectedFacility or not field or not damageSide then
        return false
    end

    if not combatLogic.canAssignDamageToSide(targetSide) then
        return false
    end

    cutIn.pendingEliminations[targetSide] = cutIn.pendingEliminations[targetSide] or {}

    for _, entry in ipairs(unitTesting[field] or {}) do
        if entry.fac == selectedFacility.id
            and entry.unit == unitId
            and getEntryCount(entry) - getPendingEliminations(targetSide, unitId) > 0 then
            cutIn.pendingEliminations[targetSide][unitId] = getPendingEliminations(targetSide, unitId) + 1
            cutIn.attackRoll.tallies[damageSide].damage = math.max(0, (cutIn.attackRoll.tallies[damageSide].damage or 0) - 1)
            sfx.play("destroy")
            return true
        end
    end

    return false
end

function combatLogic.finalizeUnitElimination(targetSide, unitId)
    if not unitId or getPendingEliminations(targetSide, unitId) <= 0 then
        return false
    end

    local selectedFacility = locationFacGeo.getSelectedFacility()
    local field = ROW_FIELDS[targetSide]

    if not selectedFacility or not field then
        return false
    end

    for _, entry in ipairs(unitTesting[field] or {}) do
        if entry.fac == selectedFacility.id and entry.unit == unitId and getEntryCount(entry) > 0 then
            entry.num = getEntryCount(entry) - 1
            cutIn.pendingEliminations[targetSide][unitId] = getPendingEliminations(targetSide, unitId) - 1

            if cutIn.pendingEliminations[targetSide][unitId] <= 0 then
                cutIn.pendingEliminations[targetSide][unitId] = nil
            end

            return true
        end
    end

    return false
end

local function resetDamageStepState()
    cutIn.attackRoll = {
        active = false,
        queue = {},
        currentIndex = 0,
        current = nil,
        tallies = {
            hostile = {},
            player = {},
        },
    }
    cutIn.fireDamageResolution = {
        active = false,
        steps = {},
    }
    cutIn.pendingEliminations = {
        hostile = {},
        player = {},
    }
end

function combatLogic.advanceCompletedDamagePhase()
    if combatLogic.isFireDamageEliminationActive()
        or combatLogic.isFireDamageResolutionActive() then
        return false
    end

    local nextPhase = NEXT_PHASE_BY_DAMAGE_PHASE[cutIn.selectedPhase]

    if not nextPhase then
        return false
    end

    if getUnitCount("hostile") == 0 or getUnitCount("player") == 0 then
        return false
    end

    cutIn.selectedPhase = nextPhase
    resetDamageStepState()
    return true
end

function combatLogic.eliminateHostileUnit(unitId)
    return combatLogic.assignDamageToUnit("hostile", unitId)
end

function combatLogic.finalizeHostileElimination(unitId)
    return combatLogic.finalizeUnitElimination("hostile", unitId)
end

return combatLogic
