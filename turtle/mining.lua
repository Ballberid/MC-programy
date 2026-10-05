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
local obstacles = require("obstacles")
local maxAttempts = 32
local completedCells = {}
local timing=require("mining_timing")

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
local function stepTo(target, box, progress)
    if not config.isPoint(target) or not cuboid.contains(box, target) then return false, "dig_outside_area" end
    if not adjacentPoint(target) then return false, "dig_target_not_adjacent" end
    for attempt = 1, maxAttempts do
        local permitted, denied = nav.checkpoint()
        if not permitted then return false, denied end
        timing.phase("supplies")
        local ready, reason, info = supplies.ensure({ moves = 1, freeSlots = 2, endpoint = target, unloadFuel = true })
        timing.phase("checks")
        if not ready then return false, reason end
        if not adjacentPoint(target) then return false, "work_position_changed" end
        local synced, syncErr = nav.checkPosition()
        if not synced then return false, syncErr end
        local side, sideErr = facing(target)
        if not side then return false, sideErr end
        local clear, waitErr, hasBlock, block = obstacles.waitForTurtle(side, nav.checkpoint)
        if not clear then return false, waitErr end
        if hasBlock then
            if block.name == "minecraft:lava" or block.name == "minecraft:water" then return false, "fluid_in_area:" .. block.name end
            local peripheralSide = side == "up" and "top" or (side == "down" and "bottom" or "front")
            if peripheral.hasType(peripheralSide, "inventory") then return false, "inventory_in_area" end
        end
        if hasBlock and detect(side) then
            telemetry.setActivity("mining")
            timing.phase("dig")
            local broken, digErr = dig(side)
            timing.phase("checks")
            if not broken then return false, "dig_failed:" .. tostring(digErr) end
            if progress then progress.dug = progress.dug + 1 end
            -- Sand/gravel may fall before the next step. Recheck the inventory
            -- before every additional dig, including when still in one cell.
        end
        do
            timing.phase("move")
            -- Navigation inspects the cell again before moving. It handles
            -- falling blocks and other turtles without an extra detect here.
            local options = info and info.navigationOptions
            local optionsErr
            if not options then options,optionsErr=supplies.navigationOptions() end
            if not options then return false, optionsErr end
            -- The successful step updates the tracked coordinates. GPS is
            -- checked at the configured interval rather than for every block.
            options.positionVerified=true
            local moved, moveErr = nav.step(side, options)
            timing.phase("checks")
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

function mining.stepTo(target,box,progress)
    return timing.measure(stepTo,target,box,progress)
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

local function run(a, b, heading, previous)
    local box, err = mining.validateArea(a, b)
    if not box then return false, err end
    completedCells = {}
    local resumed = 0
    if previous then
        if type(previous) ~= "table" or previous.total ~= box.volume then return false, "checkpoint_area_mismatch" end
        resumed = math.min(box.volume, math.max(0, math.floor(previous.visited or 0)))
        for index = 1, resumed do
            local cell = cuboid.cell(box, index, a)
            completedCells[cell.x .. "," .. cell.y .. "," .. cell.z] = true
            if index % 200 == 0 then sleep(0) end
        end
    end
    local progress = { visited = resumed, completed = resumed, remaining = box.volume-resumed,
        total = box.volume, dug = previous and previous.dug or 0, phase = "prepare" }
    if previous then telemetry.log("Obnovujem segment: overim prejdenu cast " .. resumed .. "/" .. box.volume .. ", potom dokoncim zvysok.") end
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
    local c = config.load()
    local output = c.stations.output
    local function prepare()
        local prepared, prepareErr = supplies.prepare(heading)
        if not prepared then return fail(prepareErr) end
        if stations.isManaged() then
            local goal=assert(require("work_fuel").new("quarry",a,b))()
            progress.startFuelTarget=math.min(goal,turtle.getFuelLimit())
            if not fuel.has(goal) then
                local filled,fillErr=stations.refuel(goal,{capToLimit=true,allowPartial=true,anchor=nav.getPosition()})
                if not filled then return fail(fillErr) end
            end
        end
        local workStart = nav.getPosition()
        -- Verify output before damaging the first block.
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
        if not stations.isManaged() and not fuel.has(required) then
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

        if not stations.isManaged() and nav.distance(nav.getPosition(), workStart) > 0 then
            local restored, restoreErr = travel(workStart, true)
            if not restored then return fail(restoreErr) end
        end
        return true
    end
    local prepared,prepareErr,prepareProgress=stations.startup(prepare)
    if not prepared then return false,prepareErr,prepareProgress end

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
        progress.visited, progress.phase = math.max(progress.visited, index), "mining"
        telemetry.emit("info", "quarry_progress", progress, index == 1 or index == box.volume)
        if index % 64 == 0 then
            telemetry.log("Vykopane miesta: " .. index .. "/" .. box.volume, "info", progress)
        end
    end
    progress.phase = "unloading"
    local finishTravel, finishErr = travel(output)
    if not finishTravel then return fail(finishErr) end
    local options = supplies.navigationOptions(); options.keepFuel = false
    local unloaded, unloadErr = stations.unload({}, options)
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

function mining.run(a, b, heading, previous)
    local goal, err = require("work_fuel").new("quarry", a, b)
    if not goal then return false, err end
    timing.reset()
    local result=table.pack(pcall(supplies.withFuelGoal,goal, run, a, b, heading, previous))
    timing.flush()
    if not result[1] then error(result[2],0) end
    return table.unpack(result,2,result.n)
end

return mining
