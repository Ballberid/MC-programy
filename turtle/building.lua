local config = require("config")
local cuboid = require("cuboid")
local plan = require("floor_plan")
local position = require("position")
local nav = require("navigation")
local supplies = require("supplies")
local stations = require("stations")
local inv = require("inventory")
local fuel = require("fuel")
local telemetry = require("telemetry")
local building = {}

function building.validateArea(a, b)
    local box, err = plan.new(a, b)
    if not box then return nil, err end
    local c, reason = config.load()
    if not c then return nil, reason end
    for _, role in ipairs({ "fuel", "materials" }) do
        if not c.stations[role] then return nil, "station_missing:" .. role end
    end
    local protected = plan.protected(box)
    for name, s in pairs(c.stations) do
        if cuboid.contains(protected, position.offset(s, s.direction, s.side)) or cuboid.contains(box, s) then
            return nil, "station_inside_floor:" .. name
        end
    end
    if c.home and cuboid.contains(box, c.home) then return nil, "home_inside_floor" end
    return box
end

function building.run(a, b, blockName, heading, wholeArea)
    local box, err = building.validateArea(a, b)
    if not box then return false, err end
    if blockName ~= nil and (type(blockName) ~= "string" or not blockName:match("^[%w_%-]+:[%w_/%.-]+$")) then
        return false, "invalid_block_name"
    end
    local original = config.load()
    local c = require("fleet_store").copy(original)
    local selected = turtle.getSelectedSlot()
    local paths = require("pathfinding")
    -- Fleet workers avoid the entire shared floor, including neighbours' tiles.
    local previousAvoid = paths.setAvoid(wholeArea or box)
    local p = { total = box.volume, completed = 0, remaining = box.volume,
        placed = 0, skipped = 0, taskType = "floor", phase = "prepare" }
    telemetry.setProgress(p)
    local function protectMaterial()
        -- Planks/logs used for construction must never be burned as fuel.
        c.protectedItems[blockName] = true
        local ok, reason = config.save(c)
        if not ok then return false, reason end
        nav.configure(c)
        return true
    end
    local function routeCost(target, from)
        return nav.knownDistance(target, from) or (nav.estimateDistance(target, from) + 6 * c.navigation.maxDetour)
    end
    local function travel(target, direct)
        local cost = direct and 1 or routeCost(target)
        local ok, reason = supplies.ensure({ moves = cost, endpoint = direct and target or nil })
        if not ok then return false, reason end
        local options = assert(supplies.navigationOptions())
        if direct then options.maxMoves, options.maxDetour = 1, 0 end
        return nav.moveToCoord(target.x, target.y, target.z, options)
    end
    local function restock()
        if inv.count(blockName) > 0 then return true end
        local moves = 2 * routeCost(c.stations.materials) + 1
        local reserved, emptyReserved = {}, 0
        for _, slot in ipairs(c.fuelSlots) do
            if not reserved[slot] and turtle.getItemCount(slot) == 0 then emptyReserved = emptyReserved + 1 end
            reserved[slot] = true
        end
        if emptyReserved == 16 then return false, "no_material_slot" end
        local ok, reason = supplies.ensure({ moves = moves, freeSlots = 1 + emptyReserved })
        if not ok then return false, reason end
        local options = assert(supplies.navigationOptions())
        options.allowPartialMaterials, options.exactMaterials = true, true
        return stations.takeMaterials({ [blockName] = math.min(64, p.remaining) }, options)
    end
    local function work()
        if blockName then
            local ok, reason = protectMaterial(); if not ok then return false, reason end
        end
        local ready, reason = supplies.prepare(heading)
        if not ready then return false, reason end
        if cuboid.contains(wholeArea or box, nav.getPosition()) then return false, "turtle_inside_floor_plane" end
        if not blockName then
            local enough, why = supplies.ensure({ moves = 2 * routeCost(c.stations.materials), freeSlots = 1 })
            if not enough then return false, why end
            blockName, reason = stations.discoverMaterial(assert(supplies.navigationOptions()))
            if not blockName then return false, reason end
            local protected, protectErr = protectMaterial(); if not protected then return false, protectErr end
        end
        p.block = blockName
        telemetry.log("Podlaha: " .. box.volume .. " blokov; material " .. blockName)
        local _, first = plan.cell(box, 1, a)
        local _, last = plan.cell(box, box.volume, a)
        -- Two times work, travel, replenishment and the fuel-return reserve.
        local batches = math.ceil(box.volume / 64)
        local serviceTrip = math.max(routeCost(c.stations.materials, first), routeCost(c.stations.materials, last))
        local required = 2 * (box.volume + routeCost(first) + routeCost(c.home, last)
            + 2 * batches * serviceTrip + 2 * routeCost(c.stations.fuel) + c.navigation.reserve)
        p.startFuelRequired = required
        if not fuel.has(required) then
            local distance = nav.knownDistance(c.stations.fuel)
            if not distance then return false, "fuel_route_unknown" end
            local options = assert(supplies.navigationOptions()); options.allowPartial = true
            local target = math.min(required, math.max(0, turtle.getFuelLimit() - distance))
            p.startFuelTarget = target
            local filled, fillErr = stations.refuel(target, options)
            if not filled then return false, fillErr end
        end
        for index = 1, box.volume do
            local allowed, denied = nav.checkpoint(); if not allowed then return false, denied end
            local block, stand = plan.cell(box, index, a)
            p.phase = "building"
            if nav.distance(nav.getPosition(), stand) > 0 then
                local moved, moveErr = travel(stand, index > 1)
                if not moved then return false, "floor_travel_failed:" .. tostring(moveErr) end
            end
            local synced, syncErr = nav.sync(); if not synced then return false, syncErr end
            if nav.distance(nav.getPosition(), stand) ~= 0 then return false, "work_position_changed" end
            local occupied, existing = turtle.inspectDown()
            if occupied then
                if existing.name ~= blockName then
                    return false, "floor_occupied:" .. block.x .. "," .. block.y .. "," .. block.z .. ":" .. existing.name
                end
                p.skipped = p.skipped + 1
            else
                local supplied, supplyErr = restock(); if not supplied then return false, supplyErr end
                allowed, denied = nav.checkpoint(); if not allowed then return false, denied end
                synced, syncErr = nav.sync(); if not synced then return false, syncErr end
                if nav.distance(nav.getPosition(), stand) ~= 0 then return false, "work_position_changed" end
                occupied, existing = turtle.inspectDown()
                if occupied then return false, "floor_changed_during_service" end
                if not inv.select(blockName) then return false, "materials_missing" end
                telemetry.setActivity("building_floor")
                local placed, placeErr = turtle.placeDown()
                if not placed then return false, "place_failed:" .. tostring(placeErr) end
                -- placeDown also accepts non-block items; verify the actual block.
                local present, built = turtle.inspectDown()
                if not present or built.name ~= blockName then return false, "placed_block_mismatch" end
                p.placed = p.placed + 1
            end
            paths.mark(block, false)
            p.completed, p.remaining = index, box.volume - index
            telemetry.emit("info", "floor_progress", p, index == 1 or index == box.volume)
        end
        p.phase = "returning"
        if inv.count(blockName) > 0 then
            local enough, why = supplies.ensure({ moves = 2 * routeCost(c.stations.materials) })
            if not enough then return false, why end
            local returned, returnErr = stations.returnMaterial(blockName, assert(supplies.navigationOptions()))
            if not returned then return false, returnErr end
        end
        local moved, moveErr = travel(c.home); if not moved then return false, moveErr end
        local turned, turnErr = nav.turnToDirection(c.home.direction); if not turned then return false, turnErr end
        p.phase, p.returnedHome = "complete", true
        telemetry.setActivity("floor_complete")
        telemetry.log("Podlaha hotova: " .. p.completed .. "/" .. p.total .. "; polozene " .. p.placed .. "; existujuce " .. p.skipped)
        return true
    end
    local ran, ok, reason = pcall(work)
    if not ran then reason, ok = tostring(ok), false end
    if not ok then
        p.phase = "failed"
        telemetry.log("Stavanie zastavene: " .. tostring(reason), "error", p)
        if nav.getPosition() and not tostring(reason):find("Terminated", 1, true) then
            local options = supplies.navigationOptions()
            if options then
                local returned, home, homeErr = pcall(nav.goHome, options)
                p.returnedHome, p.returnError = returned and home == true, returned and homeErr or tostring(home)
            end
        end
    end
    turtle.select(selected)
    paths.setAvoid(previousAvoid)
    local restored, restoreErr = config.save(original)
    nav.configure(original)
    if not restored then return false, "settings_restore_failed:" .. tostring(restoreErr), p end
    if tostring(reason):find("Terminated", 1, true) then error(reason, 0) end
    return ok == true, reason, p
end
return building
