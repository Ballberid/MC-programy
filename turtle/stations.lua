local config = require("config")
local nav = require("navigation")
local fuel = require("fuel")
local inv = require("inventory")
local telemetry = require("telemetry")
local stations = {}
local acquire, release
function stations.setRuntime(lockHandler, releaseHandler)
    acquire, release = lockHandler, releaseHandler
end

local function settings()
    return config.load()
end

local function transfer(side, take, count)
    local methods = take and { front = turtle.suck, up = turtle.suckUp, down = turtle.suckDown }
        or { front = turtle.drop, up = turtle.dropUp, down = turtle.dropDown }
    return methods[side](count)
end

local function isContainer(side)
    local name = side == "front" and "front" or (side == "up" and "top" or "bottom")
    return peripheral.hasType(name, "inventory")
end

function stations.get(name)
    local c, err = settings()
    if not c then return nil, err end
    if not c.stations[name] then return nil, "station_missing:" .. name end
    return c.stations[name]
end

function stations.visit(name, options)
    local station, err = stations.get(name)
    if not station then return false, err end
    local o = {}
    for key, value in pairs(options or {}) do o[key] = value end
    o.direction = station.direction
    local ok, reason = nav.moveToCoord(station.x, station.y, station.z, o)
    if not ok then return false, reason end
    if not isContainer(station.side) then return false, "station_inventory_missing" end
    telemetry.setActivity("station:" .. name)
    return true, station
end

-- Always attempt to return, including after an empty/full chest error.
local function withVisit(name, action, options)
    if not nav.getPosition() then
        local ok, err = nav.init()
        if not ok then return false, err end
    end
    local start = nav.getPosition()
    if acquire then
        local ok, err = acquire("service")
        if not ok then return false, err end
    end
    local selected = turtle.getSelectedSlot()
    local o = {}
    for key, value in pairs(options or {}) do o[key] = value end
    o.anchor = o.anchor or start
    local arrived, stationOrErr = stations.visit(name, o)
    local actionOK, actionErr = false, stationOrErr
    if arrived then
        local ran, ok, err = pcall(action, stationOrErr, start)
        if not ran and tostring(ok):find("Terminated", 1, true) then error(ok, 0) end
        if not ran then actionErr = tostring(ok)
        else actionOK, actionErr = ok, err end
    end
    turtle.select(selected)
    -- Known route avoids spending fuel on speculative shortcuts on the way back.
    local returned, returnErr = nav.moveToCoord(start.x, start.y, start.z, {
        anchor = o.anchor, reserve = o.reserve, knownOnly = true,
        maxMoves = o.maxMoves, maxDetour = o.maxDetour, direction = start.direction,
    })
    if not returned then return false, "return_failed:" .. tostring(returnErr), actionErr end
    if release then release("service") end
    return actionOK, actionErr
end

function stations.verify(name, options)
    return withVisit(name, function() return true end, options)
end

function stations.refuel(target, options)
    local c, configErr = settings()
    if not c then return false, configErr end
    local o = {}
    for key, value in pairs(options or {}) do o[key] = value end
    -- When the tank is low, do not spend the verified return budget exploring
    -- a speculative shortcut. Use the known fuel route if one is available.
    if o.knownOnly == nil and c.stations.fuel and nav.knownDistance(c.stations.fuel) then o.knownOnly = true end
    return withVisit("fuel", function(station, start)
        local distance, err = nav.knownDistance(start)
        if not distance then return false, err end
        -- nil means fill the tank AT the station; a full tank cannot include
        -- extra capacity for the subsequent trip back to the work point.
        local required = target == nil and turtle.getFuelLimit() or target + distance
        if options and options.capToLimit and fuel.level() ~= "unlimited" then required = math.min(required, turtle.getFuelLimit()) end
        local minimum = distance + (options and options.reserve or c.navigation.reserve) + 2
        local function partialOrError(reason)
            if options and options.allowPartial and fuel.has(minimum) then return true end
            return false, reason
        end
        if fuel.level() ~= "unlimited" and required > turtle.getFuelLimit() then return false, "fuel_target_exceeds_limit" end
        fuel.refuel(required, fuel.slots(c))
        -- At most 16 newly collected stacks. Empty/full/mixed chests terminate.
        for _ = 1, 16 do
            if fuel.has(required) then return true end
            local slot
            for _, candidate in ipairs(fuel.slots(c)) do
                if turtle.getItemCount(candidate) == 0 then slot = candidate; break end
            end
            if not slot then return partialOrError("no_slot_for_fuel") end
            turtle.select(slot)
            if not transfer(station.side, true, 64) then return partialOrError("fuel_chest_empty") end
            if not turtle.refuel(0) then
                if not transfer(station.side, false, turtle.getItemCount(slot)) then return false, "unexpected_fuel_item_cannot_return" end
                return false, "fuel_chest_contains_nonfuel"
            end
            fuel.refuel(required, { slot })
            -- Leave unused newly collected fuel in its source chest. Otherwise
            -- a mining unload would move the remaining supply into output.
            local leftover = turtle.getItemCount(slot)
            if leftover > 0 and turtle.refuel(0) then
                transfer(station.side, false, leftover)
                if turtle.getItemCount(slot) > 0 then return false, "unused_fuel_cannot_return" end
            end
        end
        if fuel.has(required) then return true end
        return partialOrError("fuel_transfer_limit")
    end, o)
end

function stations.fillFuel(options)
    if fuel.level() == "unlimited" then return true end
    local o = { allowPartial = true }
    for key, value in pairs(options or {}) do o[key] = value end
    return stations.refuel(nil, o)
end

function stations.unload(keep, options)
    keep = keep or {}
    local c, err = settings()
    if not c then return false, err end
    return withVisit("output", function(station)
        local kept = {}
        for slot = 1, 16 do
            local item = turtle.getItemDetail(slot)
            if item then
                turtle.select(slot)
                local preserveFuel = not options or options.keepFuel ~= false
                local reservedSlot = false
                for _, value in ipairs(c.fuelSlots) do if slot == value then reservedSlot = true end end
                local protected = c.protectedItems[item.name] == true or reservedSlot or (preserveFuel and turtle.refuel(0))
                local retain = protected and item.count
                    or math.min(item.count, math.max(0, (keep[item.name] or 0) - (kept[item.name] or 0)))
                kept[item.name] = (kept[item.name] or 0) + retain
                local amount = item.count - retain
                if amount > 0 then
                    local before = turtle.getItemCount(slot)
                    transfer(station.side, false, amount)
                    if before - turtle.getItemCount(slot) ~= amount then return false, "output_chest_full" end
                end
            end
        end
        return true
    end, options)
end

function stations.takeMaterials(materials, options)
    local c, configErr = settings()
    if not c then return false, configErr end
    local reserved = {}
    for _, slot in ipairs(c.fuelSlots) do reserved[slot] = true end
    return withVisit("materials", function(station)
        if inv.hasMaterials(materials) then return true end
        local before = {}
        for slot = 1, 16 do before[slot] = turtle.getItemDetail(slot) end
        local reason = "materials_missing"
        for _ = 1, 16 do
            local slot
            for _, candidate in ipairs(inv.freeSlotList()) do
                if not reserved[candidate] then slot = candidate; break end
            end
            if not slot then
                for candidate = 1, 16 do
                    local item = turtle.getItemDetail(candidate)
                    if not reserved[candidate] and item and materials[item.name] and inv.count(item.name) < materials[item.name]
                        and turtle.getItemSpace(candidate) > 0 then slot = candidate; break end
                end
            end
            if not slot then reason = "inventory_full"; break end
            turtle.select(slot)
            local needed = 0
            for name, amount in pairs(materials) do needed = math.max(needed, amount - inv.count(name)) end
            if not options or not options.exactMaterials then needed = 64 end
            if not transfer(station.side, true, math.min(64, needed, turtle.getItemSpace(slot))) then break end
            if inv.hasMaterials(materials) then break end
        end
        -- Suck may choose another acceptable slot. Inspect ALL slot deltas,
        -- rather than assuming the selected slot received the entire stack.
        for slot = 1, 16 do
            local item = turtle.getItemDetail(slot)
            if item and not materials[item.name] then
                local old = before[slot]
                local amount = item.count - (old and old.name == item.name and old.count or 0)
                turtle.select(slot)
                if amount > 0 then
                    transfer(station.side, false, amount)
                    if turtle.getItemCount(slot) ~= item.count - amount then return false, "unwanted_item_cannot_return" end
                end
            end
        end
        if not inv.hasMaterials(materials) then
            if not options or not options.allowPartialMaterials then return false, reason end
            for name, amount in pairs(materials) do
                if amount > 0 and inv.count(name) == 0 then return false, reason end
            end
        end
        return true
    end, options)
end

-- A dedicated chest contains one building block type. Sample one item and
-- return it, inspecting all slots because suck may choose a different slot.
function stations.discoverMaterial(options)
    local ok, value = withVisit("materials", function(station)
        local slot = inv.freeSlotList()[1]
        if not slot then return false, "inventory_full" end
        local before = {}
        for i = 1, 16 do before[i] = turtle.getItemCount(i) end
        turtle.select(slot)
        if not transfer(station.side, true, 1) then return false, "materials_chest_empty" end
        for i = 1, 16 do
            if turtle.getItemCount(i) > before[i] then
                local item = turtle.getItemDetail(i)
                turtle.select(i)
                transfer(station.side, false, 1)
                if turtle.getItemCount(i) ~= before[i] then return false, "material_sample_cannot_return" end
                return true, item.name
            end
        end
        return false, "material_sample_missing"
    end, options)
    if not ok then return nil, value end
    return value
end

function stations.returnMaterial(name, options)
    return withVisit("materials", function(station)
        for slot = 1, 16 do
            local item = turtle.getItemDetail(slot)
            if item and item.name == name then
                turtle.select(slot)
                transfer(station.side, false, item.count)
                if turtle.getItemCount(slot) > 0 then return false, "materials_chest_full" end
            end
        end
        return true
    end, options)
end

return stations
