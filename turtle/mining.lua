local config = require("config")
local cuboid = require("cuboid")
local nav = require("navigation")
local position = require("position")
local supplies = require("supplies")
local stations = require("stations")
local fuel = require("fuel")
local telemetry = require("telemetry")
local mining = {}
local quarryEntry = require("quarry_entry")
local maxAttempts = 32
local completedCells = {}

local function markCompleted(target, progress)
    if not progress or progress.completed == nil then return end
    local key = target.x .. "," .. target.y .. "," .. target.z
    if not completedCells[key] then
        completedCells[key] = true
        progress.completed = progress.completed + 1
        progress.remaining = progress.total - progress.completed
    end
end

local function facing(target)
    local p = nav.getPosition()
    if target.y > p.y then return "up" end
    if target.y < p.y then return "down" end
    local d
    if target.x > p.x then d = 1
    elseif target.x < p.x then d = 3
    elseif target.z > p.z then d = 2
    else d = 0 end
    local ok, err = nav.turnToDirection(d)
    if not ok then return nil, err end
    return "front"
end

local function inspect(side)
    return ({ front = turtle.inspect, up = turtle.inspectUp, down = turtle.inspectDown })[side]()
end

local function detect(side)
    return ({ front = turtle.detect, up = turtle.detectUp, down = turtle.detectDown })[side]()
end

local function dig(side)
    return ({ front = turtle.dig, up = turtle.digUp, down = turtle.digDown })[side]()
end

local function adjacentPoint(target)
    local p = nav.getPosition()
    return p and nav.distance(p, target) == 1
end

-- The only destructive movement function. Target must be one adjacent cell
-- INSIDE the requested box. Services and entry travel use normal navigation.
function mining.stepTo(target, box, progress)
    if not config.isPoint(target) or not cuboid.contains(box, target) then return false, "dig_outside_area" end
    if not adjacentPoint(target) then return false, "dig_target_not_adjacent" end
    for attempt = 1, maxAttempts do
        local permitted, denied = nav.checkpoint()
        if not permitted then return false, denied end
        local ready, reason = supplies.ensure({ moves = 1, freeSlots = 2, endpoint = target, unloadFuel = true })
        if not ready then return false, reason end
        if not adjacentPoint(target) then return false, "work_position_changed" end
        local synced, syncErr = nav.sync()
        if not synced then return false, syncErr end
        local side, sideErr = facing(target)
        if not side then return false, sideErr end
        local hasBlock, block = inspect(side)
        if hasBlock then
            if block.name == "minecraft:lava" or block.name == "minecraft:water" then return false, "fluid_in_area:" .. block.name end
            if block.name:match("^computercraft:turtle") then return false, "turtle_in_area" end
            local peripheralSide = side == "up" and "top" or (side == "down" and "bottom" or "front")
            if peripheral.hasType(peripheralSide, "inventory") then return false, "inventory_in_area" end
        end
        if detect(side) then
            telemetry.setActivity("mining")
            local broken, digErr = dig(side)
            if not broken then return false, "dig_failed:" .. tostring(digErr) end
            if progress then progress.dug = progress.dug + 1 end
            -- Sand/gravel may fall before the next step. Recheck the inventory
            -- before every additional dig, including when still in one cell.
        end
        if not detect(side) then
            local options, optionsErr = supplies.navigationOptions()
            if not options then return false, optionsErr end
            local moved, moveErr = nav.step(side, options)
            if moved then
                markCompleted(target, progress)
                telemetry.emit("info", "quarry_progress", nil)
                return true
            end
            if moveErr ~= "no_route" and moveErr ~= "target_unreachable" then return false, moveErr end
        end
        if attempt < maxAttempts then sleep(0.2) end
    end
    return false, "dig_or_move_retry_limit"
end

local function connectInside(target, box, progress)
    -- A connector is necessary only when starting inside the box. Never tunnel
    -- through the space between an external start and the selected area.
    for _, axis in ipairs({ "y", "x", "z" }) do
        while nav.getPosition()[axis] ~= target[axis] do
            local p = nav.getPosition()
            local nextPoint = { x = p.x, y = p.y, z = p.z }
            nextPoint[axis] = nextPoint[axis] + (target[axis] > p[axis] and 1 or -1)
            local ok, err = mining.stepTo(nextPoint, box, progress)
            if not ok then return false, err end
        end
    end
    return true
end

local function travel(target, knownOnly)
    local c = config.load()
    local start = nav.getPosition()
    telemetry.log("Presun z " .. start.x .. "," .. start.y .. "," .. start.z
        .. " na " .. target.x .. "," .. target.y .. "," .. target.z
        .. "; palivo " .. tostring(fuel.level()), "info")
    local distance = nav.knownDistance(target) or (nav.estimateDistance(target) + 6 * c.navigation.maxDetour)
    local ready, err = supplies.ensure({ moves = distance, freeSlots = 2, unloadFuel = true })
    if not ready then
        telemetry.log("Presun zastaveny pri kontrole zasob: " .. tostring(err), "error")
        return false, err
    end
    local options, optionsErr = supplies.navigationOptions()
    if not options then return false, optionsErr end
    options.knownOnly = knownOnly == true
    local moved, moveErr, details = nav.moveToCoord(target.x, target.y, target.z, options)
    if not moved then
        telemetry.log("Navigacia zastavena: " .. tostring(moveErr)
            .. "; prejdene kroky " .. tostring(details and details.moved or 0), "error")
    end
    return moved, moveErr, details
end

function mining.validateArea(a, b)
    local box, err = cuboid.new(a, b)
    if not box then return nil, err end
    local c, configErr = config.load()
    if not c then return nil, configErr end
    for _, name in ipairs({ "fuel", "output" }) do
        if not c.stations[name] then return nil, "station_missing:" .. name end
    end
    for name, station in pairs(c.stations) do
        local chest = position.offset(station, station.direction, station.side)
        if cuboid.contains(box, chest) then return nil, "station_inside_area:" .. name end
    end
    return box
end

function mining.run(a, b, heading)
    local box, err = mining.validateArea(a, b)
    if not box then return false, err end
    completedCells = {}
    local progress = { visited = 0, completed = 0, remaining = box.volume, total = box.volume, dug = 0, phase = "prepare" }
    telemetry.setProgress(progress)
    telemetry.emit("info", "quarry_progress", nil, true)
    local function fail(reason)
        progress.phase = "failed"
        telemetry.log("Kopanie zastavene: " .. tostring(reason), "error", progress)
        -- Keep the original failure, but report whether retreat succeeded.
        -- No digging during retreat; unknown/blocked routes may prevent it.
        if nav.getPosition() then
            local options = supplies.navigationOptions()
            if options then
                local home, homeErr = nav.goHome(options)
                progress.returnedHome, progress.returnError = home, homeErr
            end
        end
        return false, reason, progress
    end
    local prepared, prepareErr = supplies.prepare(heading)
    if not prepared then return fail(prepareErr) end
    local workStart = nav.getPosition()
    -- Verify output before damaging the first block.
    local c = config.load()
    local output = c.stations.output
    local reached, reachErr = travel(output)
    if not reached then return fail(reachErr) end
    local options = supplies.navigationOptions()
    options.keepFuel = false
    local unloaded, unloadErr = stations.unload({}, options)
    if not unloaded then return fail(unloadErr) end

    -- Double the entire estimate: work, travel and safety reserves.
    local function routeCost(from, target)
        return nav.knownDistance(target, from)
            or (nav.estimateDistance(target, from) + 6 * c.navigation.maxDetour)
    end
    local lastCell = cuboid.cell(box, box.volume, a)
    local required = 2 * (box.volume + routeCost(nav.getPosition(), workStart)
        + routeCost(workStart, a) + routeCost(lastCell, output)
        + routeCost(output, c.home) + 2 * routeCost(nav.getPosition(), c.stations.fuel)
        + c.navigation.reserve)
    progress.startFuelRequired = required
    if not fuel.has(required) then
        telemetry.setActivity("quarry_refuel")
        -- refuel(target) also reserves the trip back from the fuel station.
        local returnDistance = nav.knownDistance(c.stations.fuel)
        if not returnDistance then return fail("fuel_route_unknown") end
        local limit = turtle.getFuelLimit()
        local target = math.min(required, math.max(0, limit - returnDistance))
        progress.startFuelTarget = target
        options.allowPartial = true
        telemetry.log("Doplnam palivo: ciel po navrate " .. target
            .. "; odhad " .. required .. "; limit " .. limit, "info")
        local filled, fillErr = stations.refuel(target, options)
        if not filled then return fail(fillErr) end
        telemetry.log("Palivo po doplneni a navrate: " .. tostring(fuel.level()), "info")
    else
        telemetry.log("Palivo staci, tankovanie preskakujem: " .. tostring(fuel.level())
            .. "; odhad s rezervou " .. required, "info")
    end

    if nav.distance(nav.getPosition(), workStart) > 0 then
        local restored, restoreErr = travel(workStart, true)
        if not restored then return fail(restoreErr) end
    end

    progress.phase = "entry"
    local entry, entryErr = quarryEntry.enter(box, progress, travel, mining.stepTo, connectInside, a)
    if not entry then return fail(entryErr) end
    for index = 1, box.volume do
        local target = cuboid.cell(box, index, entry)
        if nav.distance(nav.getPosition(), target) > 0 then
            local mined, mineErr = mining.stepTo(target, box, progress)
            if not mined then return fail(mineErr) end
        end
        markCompleted(target, progress)
        progress.visited, progress.phase = index, "mining"
        telemetry.emit("info", "quarry_progress", progress, index == 1 or index == box.volume)
        if index % 64 == 0 then
            telemetry.log("Vykopane miesta: " .. index .. "/" .. box.volume, "info", progress)
        end
    end
    progress.phase = "unloading"
    local finishTravel, finishErr = travel(output)
    if not finishTravel then return fail(finishErr) end
    options = supplies.navigationOptions(); options.keepFuel = false
    unloaded, unloadErr = stations.unload({}, options)
    if not unloaded then return fail(unloadErr) end
    local homeTravel, homeTravelErr = travel(c.home)
    if not homeTravel then return fail(homeTravelErr) end
    local turned, turnErr = nav.turnToDirection(c.home.direction)
    if not turned then return fail(turnErr) end
    progress.phase, progress.returnedHome = "complete", true
    telemetry.setActivity("quarry_complete")
    telemetry.log("Kopanie dokoncene: " .. progress.visited .. "/" .. progress.total, "info", progress)
    return true, nil, progress
end

return mining
