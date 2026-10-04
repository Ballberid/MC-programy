package.path = ROOT .. "/turtle/?.lua;" .. package.path
local realLoadfile = loadfile
local modules = { "config", "fuel", "inventory", "position", "pathfinding", "navigation", "stations", "supplies", "network", "telemetry", "cuboid", "mining", "quarry_entry", "fleet_store", "fleet_model", "transit", "fleet_settings", "fleet_dialog", "fleet_task", "fleet_client", "fleet_display", "fleet_controller" }
local W
local tests = 0
local function key(p) return p.x .. "," .. p.y .. "," .. p.z end
local vectors = { [0] = { 0, -1 }, { 1, 0 }, { 0, 1 }, { -1, 0 } }
local function adjacent(side)
    local p = { x = W.x, y = W.y, z = W.z }
    if side == "up" then p.y = p.y + 1
    elseif side == "down" then p.y = p.y - 1
    else
        local d = side == "back" and (W.d + 2) % 4 or W.d
        p.x = p.x + vectors[d][1]; p.z = p.z + vectors[d][2]
    end
    return p
end
local function serialize(t, seen)
    if type(t) == "string" then return string.format("%q", t) end
    if type(t) ~= "table" then return tostring(t) end
    seen = seen or {}
    assert(not seen[t], "Cannot serialize table with repeated entries")
    seen[t] = true
    local parts = {}
    for k, v in pairs(t) do parts[#parts + 1] = "[" .. serialize(k, seen) .. "]=" .. serialize(v, seen) end
    return "{" .. table.concat(parts, ",") .. "}"
end
local function reset()
    parallel = { waitForAny = function(first) return first() end }
    for _, name in ipairs(modules) do package.loaded[name] = nil end
    package.loaded.fleet_motion = nil
    package.loaded.building, package.loaded.floor_plan = nil, nil
    package.loaded.floor_access = nil
    package.loaded.fleet_floors = nil
    package.loaded.work_fuel = nil
    package.loaded.obstacles = nil
    W = { x = 0, y = 0, z = 0, d = 0, fuel = 1000, limit = 2000,
        blocks = {}, chests = {}, slots = {}, selected = 1, moves = 0, gpsCalls = 0,
        files = {}, dirs = {}, packets = {}, failSteps = 0, ticks = 0,
        digs = {}, placements = {}, unbreakable = {}, blockNames = {}, drops = {}, falling = {}, lostDrops = 0 }
    turtle = {}
    turtle.getFuelLevel = function() return W.fuel end
    turtle.getFuelLimit = function() return W.limit end
    turtle.getSelectedSlot = function() return W.selected end
    turtle.select = function(s) W.selected = s; return true end
    turtle.getItemCount = function(s) local i = W.slots[s or W.selected]; return i and i.count or 0 end
    turtle.getItemSpace = function(s) return 64 - turtle.getItemCount(s) end
    turtle.getItemDetail = function(s)
        local i = W.slots[s or W.selected]
        return i and { name = i.name, count = i.count } or nil
    end
    turtle.refuel = function(count)
        local i = W.slots[W.selected]
        if not i or i.name ~= "minecraft:coal" then return false end
        if count == 0 then return true end
        if W.fuel >= W.limit then return false end
        W.refuelAfterDig = W.refuelAfterDig or #W.digs > 0
        W.refuelCounts = W.refuelCounts or {}
        W.refuelCounts[#W.refuelCounts + 1] = count
        local amount = math.min(count or i.count, i.count, math.ceil((W.limit - W.fuel) / 80))
        W.fuel = math.min(W.limit, W.fuel + amount * 80)
        i.count = i.count - amount
        if i.count == 0 then W.slots[W.selected] = nil end
        return true
    end
    turtle.turnRight = function() W.d = (W.d + 1) % 4; return true end
    turtle.turnLeft = function() W.d = (W.d + 3) % 4; return true end
    local function detect(side)
        local k = key(adjacent(side))
        return W.blocks[k] == true or W.chests[k] ~= nil
    end
    local function move(side)
        if W.failSteps > 0 then W.failSteps = W.failSteps - 1; return false, "entity" end
        if detect(side) then return false, "block" end
        if W.fuel ~= "unlimited" and W.fuel <= 0 then return false, "fuel" end
        local p = adjacent(side)
        W.x, W.y, W.z = p.x, p.y, p.z
        if W.fuel ~= "unlimited" then W.fuel = W.fuel - 1 end
        W.moves = W.moves + 1
        return true
    end
    for _, entry in ipairs({ { "forward", "front" }, { "back", "back" }, { "up", "up" }, { "down", "down" } }) do
        local name, side = entry[1], entry[2]
        turtle[name] = function() return move(side) end
    end
    turtle.detect = function() return detect("front") end
    turtle.detectUp = function() return detect("up") end
    turtle.detectDown = function() return detect("down") end
    local function inspect(side)
        local k = key(adjacent(side))
        if W.chests[k] then return true, { name = "minecraft:chest" } end
        if not W.blocks[k] and not W.blockNames[k] then return false, "No block" end
        return true, { name = W.blockNames[k] or "minecraft:stone" }
    end
    local function dig(side)
        local p = adjacent(side)
        local k = key(p)
        if W.unbreakable[k] then return false, "Unbreakable block" end
        if not W.blocks[k] then return false, "No block" end
        W.digs[#W.digs + 1] = p
        if (W.falling[k] or 0) > 0 then W.falling[k] = W.falling[k] - 1
        else W.blocks[k], W.blockNames[k] = nil, nil end
        local name = W.drops[k] or "minecraft:cobblestone"
        for slot = 1, 16 do
            local item = W.slots[slot]
            if not item or (item.name == name and item.count < 64) then
                W.slots[slot] = { name = name, count = (item and item.count or 0) + 1 }
                return true
            end
        end
        W.lostDrops = W.lostDrops + 1
        return true
    end
    for _, entry in ipairs({ { "inspect", "front", false }, { "inspectUp", "up", false }, { "inspectDown", "down", false },
        { "dig", "front", true }, { "digUp", "up", true }, { "digDown", "down", true } }) do
        local name, side, destructive = entry[1], entry[2], entry[3]
        turtle[name] = function() if destructive then return dig(side) else return inspect(side) end end
    end
    local function suck(side, amount)
        local chest = W.chests[key(adjacent(side))]
        if not chest then return false end
        local item = chest.items[1]
        if not item then return false end
        local target
        for i = 0, 15 do
            local slot = (W.selected - 1 + i) % 16 + 1
            local existing = W.slots[slot]
            if not existing or (existing.name == item.name and existing.count < 64) then target = slot; break end
        end
        if not target then return false end
        local oldCount = W.slots[target] and W.slots[target].count or 0
        local count = math.min(item.count, amount or 64, 64 - oldCount)
        W.slots[target] = { name = item.name, count = count + oldCount }
        item.count = item.count - count
        if item.count == 0 then table.remove(chest.items, 1) end
        return true
    end
    local function place(side)
        local point = adjacent(side)
        local k = key(point)
        local item = W.slots[W.selected]
        if W.placeFailAt == k then return false, "Entity obstructing placement" end
        if detect(side) or not item then return false, "Cannot place" end
        W.blocks[k], W.blockNames[k] = true, item.name
        W.placements[#W.placements + 1] = point
        item.count = item.count - 1
        if item.count == 0 then W.slots[W.selected] = nil end
        return true
    end
    turtle.placeDown = function() return place("down") end
    turtle.placeUp = function() return place("up") end
    local function drop(side, amount)
        local chest = W.chests[key(adjacent(side))]
        local item = W.slots[W.selected]
        if not chest or not item then return false end
        local count = math.min(item.count, amount or item.count, chest.capacity or 100000)
        if count == 0 then return false end
        chest.items[#chest.items + 1] = { name = item.name, count = count }
        if chest.capacity then chest.capacity = chest.capacity - count end
        item.count = item.count - count
        if item.count == 0 then W.slots[W.selected] = nil end
        return true
    end
    for _, entry in ipairs({ { "suck", "front", true }, { "suckUp", "up", true }, { "suckDown", "down", true },
        { "drop", "front", false }, { "dropUp", "up", false }, { "dropDown", "down", false } }) do
        local name, side, take = entry[1], entry[2], entry[3]
        turtle[name] = function(n) if take then return suck(side, n) else return drop(side, n) end end
    end
    gps = { locate = function()
        W.gpsCalls = W.gpsCalls + 1
        if W.gpsFailAt and W.gpsCalls >= W.gpsFailAt then return nil end
        return W.x, W.y, W.z
    end }
    sleep = function(t) W.ticks = W.ticks + t end
    os.clock = function() return W.ticks end
    os.epoch = function() return 100000 end
    os.getComputerID = function() return 12 end
    os.getComputerLabel = function() return "Test turtle" end
    peripheral = {
        getNames = function() return W.noModem and {} or { "left" } end,
        hasType = function(name, kind)
            if kind == "modem" then return name == "left" and not W.noModem end
            if kind == "inventory" then
                local side = ({ top = "up", bottom = "down", front = "front" })[name]
                return side and W.chests[key(adjacent(side))] ~= nil or false
            end
            return false
        end,
    }
    rednet = {
        open = function() W.open = true end, isOpen = function() return W.open end,
        broadcast = function(p) W.packets[#W.packets + 1] = p end,
        send = function(id, p) W.packets[#W.packets + 1] = p; return true end,
    }
    fs = {
        exists = function(path) return W.files[path] ~= nil or W.dirs[path] == true end,
        makeDir = function(path) W.dirs[path] = true end,
        combine = function(a, b) return a .. "/" .. b end,
        delete = function(path)
            W.files[path], W.dirs[path] = nil, nil
            for k in pairs(W.files) do if k:sub(1, #path + 1) == path .. "/" then W.files[k] = nil end end
        end,
        copy = function(a, b) assert(W.files[a], "missing copy source " .. a); W.files[b] = W.files[a] end,
        move = function(a, b)
            if W.installFail and a:match("^data/update%-stage/") then W.installFail = false; error("disk failure") end
            assert(W.files[a], "missing move source " .. a)
            W.files[b], W.files[a] = W.files[a], nil
        end,
        open = function(path, mode)
            if mode == "r" then
                if not W.files[path] then return nil end
                return { readAll = function() return W.files[path] end, close = function() end }
            end
            W.files[path] = ""
            return { write = function(v) W.files[path] = W.files[path] .. v end, close = function() end }
        end,
    }
    textutils = {
        serialize = serialize,
        unserialize = function(text) local fn = load("return " .. text, "serialized", "t", {}); return fn and fn() end,
    }
end

local function eq(a, b, message)
    assert(a == b, (message or "mismatch") .. ": " .. tostring(a) .. " != " .. tostring(b))
end
local function test(name, fn)
    reset()
    local ok, err = pcall(fn)
    if not ok then error("FAIL " .. name .. ": " .. tostring(err), 0) end
    tests = tests + 1
    print("PASS " .. name)
end
local function configured(stations)
    local config = require("config")
    local c = config.defaults()
    c.start = { x = 0, y = 0, z = 0, direction = 0 }
    c.home = { x = 0, y = 0, z = 0, direction = 0 }
    c.stations = stations or {}
    assert(config.save(c))
    return c
end
local function navReady()
    local nav = require("navigation")
    assert(nav.init(W.d))
    return nav
end
local function matchesWorld(nav)
    local p = nav.getPosition()
    eq(p.x, W.x); eq(p.y, W.y); eq(p.z, W.z); eq(p.direction, W.d)
end

test("targeted refuel and slot restoration", function()
    W.fuel = 1; W.selected = 7
    W.slots[2] = { name = "minecraft:coal", count = 10 }
    eq(require("fuel").refuel(100), 161)
    eq(W.slots[2].count, 8); eq(W.selected, 7)
end)
test("full refuel uses one bulk operation for a stack", function()
    W.fuel = 0; W.slots[1] = { name = "minecraft:coal", count = 64 }; W.selected = 7
    eq(require("fuel").refuel(), 2000)
    eq(#W.refuelCounts, 1); eq(W.refuelCounts[1], 64); eq(W.slots[1].count, 39); eq(W.selected, 7)
end)
test("targeted refuel measures one item then consumes the required batch", function()
    W.fuel = 0; W.slots[1] = { name = "minecraft:coal", count = 64 }
    eq(require("fuel").refuel(1000), 1040)
    eq(#W.refuelCounts, 2); eq(W.refuelCounts[1], 1); eq(W.refuelCounts[2], 12); eq(W.slots[1].count, 51)
end)
test("unlimited fuel", function()
    W.fuel = "unlimited"
    eq(require("fuel").refuel(), "unlimited")
    eq(require("fuel").has(100000), true)
    assert(navReady().moveToCoord(2, 2, 2))
end)
test("inventory slots, counts and partial capacity", function()
    W.slots[1] = { name = "stone", count = 32 }
    W.slots[2] = { name = "stone", count = 12 }
    W.slots[3] = { name = "dirt", count = 64 }
    local inv = require("inventory")
    eq(inv.freeSlots(), 13); eq(inv.count("stone"), 44); eq(inv.space("stone"), 13 * 64 + 84)
end)
test("config rejects corrupt directions and fills defaults", function()
    local c = configured()
    c.home.direction = 8
    eq(require("config").save(c), false)
    W.files["data/settings.txt"] = "oops"
    eq(require("config").load(), nil)
end)
test("GPS failure does not move", function()
    W.gpsFailAt = 1
    eq(require("navigation").init(), false); eq(W.moves, 0)
end)
test("heading probe restores all four headings", function()
    for d = 0, 3 do
        W.d = d
        local nav = require("navigation")
        assert(nav.init()); matchesWorld(nav); eq(W.d, d); eq(W.x, 0); eq(W.z, 0)
    end
end)
test("heading probe with rotation and vertical escape", function()
    W.blocks["0,0,-1"], W.blocks["1,0,0"], W.blocks["0,0,1"], W.blocks["-1,0,0"] = true, true, true, true
    local nav = require("navigation")
    assert(nav.init()); matchesWorld(nav); eq(W.y, 0); eq(W.d, 0)
end)
test("probe rolls back after GPS loss", function()
    W.gpsFailAt = 3
    eq(require("navigation").init(), false)
    eq(W.x, 0); eq(W.y, 0); eq(W.z, 0)
end)
test("goHome handles all headings and Y", function()
    for d = 0, 3 do
        local c = configured()
        c.home = { x = 2, y = 2, z = -2, direction = d }
        assert(require("config").save(c))
        W.d = d
        local nav = navReady()
        assert(nav.goHome()); matchesWorld(nav)
        eq(W.x, 2); eq(W.y, 2); eq(W.z, -2); eq(W.d, d)
        W.x, W.y, W.z = 0, 0, 0
    end
end)
test("failed step never changes coordinates", function()
    local nav = navReady()
    W.failSteps = 50
    local ok = nav.step("front")
    eq(ok, false); matchesWorld(nav); eq(W.moves, 0)
end)
test("obstacle reroute then known return", function()
    W.blocks["1,0,0"] = true
    local nav = navReady()
    local start = nav.getPosition()
    assert(nav.moveToCoord(3, 0, 0, { anchor = start }))
    eq(W.moves, 5); matchesWorld(nav)
    assert(nav.moveToCoord(0, 0, 0, { anchor = start, knownOnly = true, direction = 0 }))
    matchesWorld(nav); eq(W.moves, 10)
end)
test("enclosed target and search limits stop", function()
    local nav = navReady()
    W.blocks["1,0,0"] = true
    local ok, err = nav.moveToCoord(2, 0, 0, { maxDetour = 0 })
    eq(ok, false); eq(err, "no_route"); eq(W.moves, 0)
    local paths = require("pathfinding")
    local route, reason = paths.find({ x = 0, y = 0, z = 0 }, { x = 50, y = 0, z = 0 }, { maxNodes = 1 })
    eq(route, nil); eq(reason, "search_limit")
end)
test("move limit permits safe return", function()
    local nav = navReady()
    local start = nav.getPosition()
    local ok, err = nav.moveToCoord(10, 0, 0, { maxMoves = 3 })
    eq(ok, false); eq(err, "move_limit"); eq(W.x, 3)
    assert(nav.moveToCoord(0, 0, 0, { anchor = start, knownOnly = true }))
end)
test("fuel reserve stops exploration and supports retreat", function()
    W.fuel = 24
    local nav = navReady()
    local start = nav.getPosition()
    local ok, err = nav.moveToCoord(10, 0, 0, { anchor = start })
    eq(ok, false); eq(err, "fuel_reserve"); eq(W.x, 2); eq(W.fuel, 22)
    assert(nav.moveToCoord(0, 0, 0, { anchor = start, knownOnly = true }))
    eq(W.fuel, 20)
end)
test("unknown fuel anchor rejected before movement", function()
    local nav = navReady()
    local ok = nav.moveToCoord(2, 0, 0, { anchor = { x = 100, y = 0, z = 0 } })
    eq(ok, false); eq(W.moves, 0)
end)
test("GPS loss mid-route stops further movement", function()
    local nav = navReady()
    W.gpsFailAt = W.gpsCalls + 2
    local c = require("config").defaults(); c.navigation.gpsEvery = 1
    nav.configure(c)
    local ok, err = nav.moveToCoord(10, 0, 0)
    eq(ok, false); eq(err, "gps_unavailable"); eq(W.moves, 1); matchesWorld(nav)
end)
test("telemetry loss does not block movement", function()
    W.noModem = true
    local nav = navReady()
    assert(nav.moveToCoord(1, 1, 1)); matchesWorld(nav)
end)
test("telemetry packet and print restoration", function()
    local nav = navReady()
    local t = require("telemetry")
    assert(t.emit("info", "hello", nil, true)); eq(W.packets[1].id, 12)
    local original = print
    local ok = pcall(function() t.capture(function() error("test error") end) end)
    eq(ok, false); eq(print, original)
end)

test("job progress persists during services and packets keep counter snapshots", function()
    navReady()
    local t = require("telemetry")
    local progress = { completed = 52, remaining = 30700, total = 30752, dug = 52, phase = "entry" }
    t.setProgress(progress)
    assert(t.setActivity("unloading"))
    local first = W.packets[#W.packets]
    eq(first.progress.completed, 52); eq(first.progress.remaining, 30700)
    progress.completed, progress.remaining = 53, 30699
    assert(t.emit("info", "moving", nil, true))
    eq(first.progress.completed, 52); eq(W.packets[#W.packets].progress.completed, 53)
    t.setProgress(nil)
    assert(t.emit("info", "idle", nil, true)); eq(W.packets[#W.packets].progress, nil)
end)
test("fuel station visit refuels and returns", function()
    configured({ fuel = { x = 2, y = 0, z = 0, direction = 1, side = "front" } })
    W.chests["3,0,0"] = { items = { { name = "minecraft:coal", count = 16 } } }
    W.fuel = 100
    local nav = navReady()
    assert(require("stations").refuel(500))
    eq(W.x, 0); eq(W.d, 0); assert(W.fuel >= 500); matchesWorld(nav)
    eq(require("inventory").count("minecraft:coal"), 0)
    eq(W.chests["3,0,0"].items[1].count, 10)
    eq(nav.knownDistance({ x = 2, y = 0, z = 0 }), 2)
end)
test("full output chest reports partial transfer and returns", function()
    configured({ output = { x = 2, y = 0, z = 0, direction = 1, side = "front" } })
    W.chests["3,0,0"] = { items = {}, capacity = 3 }
    W.slots[1] = { name = "stone", count = 10 }
    local nav = navReady()
    local ok, err = require("stations").unload()
    eq(ok, false); eq(err, "output_chest_full"); eq(W.slots[1].count, 7)
    eq(W.x, 0); eq(W.d, 0); matchesWorld(nav)
end)
test("missing chest never drops inventory into world", function()
    configured({ output = { x = 2, y = 0, z = 0, direction = 1, side = "front" } })
    W.slots[1] = { name = "stone", count = 10 }
    navReady()
    local ok, err = require("stations").unload()
    eq(ok, false); eq(err, "station_inventory_missing"); eq(W.slots[1].count, 10); eq(W.x, 0)
end)
test("material visit returns unwanted items", function()
    configured({ materials = { x = 1, y = 0, z = 0, direction = 1, side = "front" } })
    W.chests["2,0,0"] = { items = { { name = "dirt", count = 64 }, { name = "stone", count = 20 } } }
    navReady()
    assert(require("stations").takeMaterials({ stone = 10 }))
    eq(require("inventory").count("dirt"), 0); eq(require("inventory").count("stone"), 20)
    eq(W.x, 0); eq(W.d, 0)
end)
test("supplies requires verification and accounts for work return", function()
    configured({ fuel = { x = 2, y = 0, z = 0, direction = 1, side = "front" } })
    W.chests["3,0,0"] = { items = {} }
    navReady()
    local s = require("supplies")
    eq(s.check({ moves = 10 }), false)
    assert(s.prepare())
    local ok, err, info = s.check({ moves = 10 })
    assert(ok, err); eq(info.requiredFuel, 42)
end)

test("configured fuel station is the default safety anchor", function()
    configured({ fuel = { x = 100, y = 0, z = 0, direction = 0, side = "front" } })
    local nav = navReady()
    local ok, err = nav.moveToCoord(1, 0, 0)
    eq(ok, false); assert(err:find("return_route_unknown", 1, true)); eq(W.moves, 0)
end)
test("receiver renders validated packets on a narrow screen", function()
    local lines, writes = {}, 0
    term = { current = function() return {
        clear = function() end, getSize = function() return 20, 8 end,
        setCursorPos = function(x, y) assert(x == 1 and y <= 8) end,
        write = function(text) assert(#text <= 20); writes = writes + 1; lines[#lines + 1] = text end,
    } end }
    peripheral.find = function() return nil end
    local count = 0
    rednet.receive = function()
        count = count + 1
        if count == 1 then return 12, { version = 1, id = 12, message = "hello", fuel = 55,
            position = { x = 0, y = 0, z = 0, direction = 0 }, inventory = { freeSlots = 15 }, activity = "moving", level = "info" } end
        if count == 2 then return 12, { version = 1, id = 99, message = "fake" } end
        error("end receiver simulation")
    end
    local ok, err = pcall(realLoadfile(ROOT .. "/turtle/receiver.lua"))
    eq(ok, false); assert(tostring(err):find("end receiver simulation", 1, true))
    assert(writes > 0)
    local fuelVisible, slotsVisible = false, false
    for _, line in ipairs(lines) do
        assert(not line:find("fake", 1, true))
        if line == "Palivo: 55" then fuelVisible = true end
        if line == "Volne sloty: 15" then slotsVisible = true end
    end
    assert(fuelVisible and slotsVisible, "Resource counts must fit on separate lines")
end)
test("read-only diagnostics do not move or consume items", function()
    configured()
    W.slots[1] = { name = "minecraft:coal", count = 10 }
    realLoadfile(ROOT .. "/turtle/test.lua")("check")
    eq(W.moves, 0); eq(W.slots[1].count, 10); eq(W.fuel, 1000)
end)

test("pocket display shows quarry counters with resources on separate lines", function()
    local lines = {}
    term = { current = function() return {
        clear = function() end, getSize = function() return 26, 20 end,
        setCursorPos = function(x, y) assert(x == 1 and y <= 20) end,
        write = function(text) assert(#text <= 26); lines[#lines + 1] = text end,
    } end }
    peripheral.find = function() return nil end
    local count = 0
    rednet.receive = function()
        count = count + 1
        if count > 1 then error("end receiver simulation") end
        return 12, { version = 1, id = 12, message = "working", fuel = 20000,
            inventory = { freeSlots = 15 }, progress = { completed = 52, remaining = 30700, total = 30752, dug = 53 },
            position = { x = 7489, y = 67, z = -2498, direction = 0 }, activity = "mining", level = "info" }
    end
    local ok, err = pcall(realLoadfile(ROOT .. "/turtle/receiver.lua"))
    eq(ok, false); assert(tostring(err):find("end receiver simulation", 1, true))
    local rendered = table.concat(lines, "\n")
    for _, expected in ipairs({ "Palivo: 20000", "Volne sloty: 15", "Hotove: 52/30752", "Zostava: 30700", "Rozbite bloky: 53" }) do
        assert(rendered:find(expected, 1, true), expected)
    end
end)
test("invalid navigation options rejected before movement", function()
    local nav = navReady()
    eq(nav.moveToCoord(2, 0, 0, { reserve = -1 }), false)
    eq(nav.moveToCoord(2, 0, 0, { direction = 5 }), false)
    eq(W.moves, 0)
end)
test("protected material is not burnt during navigation or probing", function()
    local c = configured(); c.protectedItems["minecraft:coal"] = true
    assert(require("config").save(c))
    W.fuel = 0; W.slots[1] = { name = "minecraft:coal", count = 64 }
    local nav = require("navigation")
    eq(nav.init(), false); eq(W.slots[1].count, 64)
    assert(nav.init(0)); eq(nav.moveToCoord(1, 0, 0), false); eq(W.slots[1].count, 64)
end)
test("fuel slot restrictions", function()
    local c = configured(); c.fuelSlots = { 16 }
    assert(require("config").save(c))
    W.fuel = 0
    W.slots[1] = { name = "minecraft:coal", count = 10 }
    W.slots[16] = { name = "minecraft:coal", count = 2 }
    assert(navReady().moveToCoord(1, 0, 0))
    eq(W.slots[1].count, 10); eq(W.slots[16].count, 1)
end)
test("GPS mismatch invalidates position", function()
    local nav = navReady()
    W.x = 100
    local ok, err = nav.moveToCoord(1, 0, 0)
    eq(ok, false); eq(err, "position_mismatch"); eq(nav.getPosition(), nil); eq(W.moves, 0)
end)
test("invalid supply requests rejected before movement", function()
    configured()
    local s = require("supplies")
    eq(s.ensure({ moves = -100 }), false)
    eq(s.check({ freeSlots = 17 }), false)
    eq(s.ensure({ materials = { stone = -1 } }), false)
    eq(W.moves, 0)
end)
test("unload preserves material quota, fuel and protected items", function()
    local c = configured({ output = { x = 0, y = 0, z = 0, direction = 1, side = "front" } })
    c.protectedItems.tool = true; assert(require("config").save(c))
    W.chests["1,0,0"] = { items = {} }
    W.slots[1] = { name = "stone", count = 64 }; W.slots[2] = { name = "stone", count = 32 }
    W.slots[3] = { name = "minecraft:coal", count = 10 }; W.slots[4] = { name = "tool", count = 1 }
    navReady(); assert(require("stations").unload({ stone = 70 }))
    eq(require("inventory").count("stone"), 70)
    eq(W.slots[3].count, 10); eq(W.slots[4].count, 1); eq(W.d, 0)
end)
test("materials can fill partial stacks with no empty slots", function()
    configured({ materials = { x = 0, y = 0, z = 0, direction = 1, side = "front" } })
    W.chests["1,0,0"] = { items = { { name = "stone", count = 32 } } }
    for slot = 1, 16 do W.slots[slot] = { name = "dirt", count = 64 } end
    W.slots[1] = { name = "stone", count = 10 }
    navReady(); assert(require("stations").takeMaterials({ stone = 20 }))
    eq(require("inventory").count("stone"), 42); eq(W.d, 0)
end)
test("empty fuel chest returns an error and restores work position", function()
    configured({ fuel = { x = 1, y = 0, z = 0, direction = 1, side = "front" } })
    W.chests["2,0,0"] = { items = {} }
    navReady()
    local ok, err = require("stations").refuel(1500)
    eq(ok, false); eq(err, "fuel_chest_empty"); eq(W.x, 0); eq(W.d, 0)
end)
test("supplies refuels, unloads and obtains material at same origin", function()
    configured({ fuel = { x = 0, y = 0, z = 0, direction = 1, side = "front" },
        output = { x = 0, y = 0, z = 0, direction = 2, side = "front" },
        materials = { x = 0, y = 0, z = 0, direction = 3, side = "front" } })
    W.chests["1,0,0"] = { items = { { name = "minecraft:coal", count = 10 } } }
    W.chests["0,0,1"] = { items = {} }
    W.chests["-1,0,0"] = { items = { { name = "stone", count = 64 } } }
    W.fuel = 30
    for slot = 1, 15 do W.slots[slot] = { name = "dirt", count = 64 } end
    navReady()
    assert(require("supplies").ensure({ moves = 30, freeSlots = 3, materials = { stone = 20 } }))
    assert(require("fuel").has(80)); assert(require("inventory").count("stone") >= 20)
    assert(require("inventory").freeSlots() >= 3); eq(W.d, 0)
end)
test("navigation waits five seconds then routes around a turtle without digging", function()
    configured(); navReady()
    W.blocks["1,0,0"]=true; W.blockNames["1,0,0"]="computercraft:turtle_advanced"
    local ok,err=require("navigation").moveToCoord(2,0,0,{maxDetour=1,maxMoves=10})
    assert(ok,err); assert(W.ticks>=5); eq(W.x,2); eq(W.z,0); eq(#W.digs,0)
    eq(W.blocks["1,0,0"],true)
end)
test("station access waits longer than five seconds for its exact parking point", function()
    configured({fuel={x=1,y=0,z=0,direction=1,side="front"}}); navReady()
    W.chests["2,0,0"]={items={}}
    W.blocks["1,0,0"]=true; W.blockNames["1,0,0"]="computercraft:turtle_advanced"
    sleep=function(seconds)
        W.ticks=W.ticks+seconds
        if W.ticks>=8 then W.blocks["1,0,0"],W.blockNames["1,0,0"]=nil,nil end
    end
    local ok,err=require("stations").verify("fuel")
    assert(ok,err); assert(W.ticks>=8); eq(W.x,0); eq(#W.digs,0)
end)
test("temporary turtle obstruction restores a previously verified route", function()
    local paths=require("pathfinding")
    for x=0,2 do paths.mark({x=x,y=0,z=0},true) end
    paths.markTemporary({x=1,y=0,z=0})
    eq(paths.find({x=0,y=0,z=0},{x=2,y=0,z=0},{knownOnly=true}),nil)
    W.ticks=6
    local route=assert(paths.find({x=0,y=0,z=0},{x=2,y=0,z=0},{knownOnly=true}))
    eq(#route,2); eq(paths.hasTemporary(),false)
end)
test("job refuelling obtains the whole goal instead of the next-step minimum", function()
    configured({fuel={x=0,y=0,z=0,direction=1,side="front"}})
    W.chests["1,0,0"]={items={{name="minecraft:coal",count=64}}}
    W.fuel=30; navReady(); assert(require("supplies").prepare())
    local supplies=require("supplies")
    assert(supplies.withFuelGoal(function() return 1000 end,function()
        return supplies.ensure({moves=20})
    end))
    assert(W.fuel>=1000 and W.fuel<1080); assert(W.fuel<W.limit)
end)
test("job refuelling caps at the station and subtracts the actual return trip", function()
    configured({fuel={x=2,y=0,z=0,direction=1,side="front"}})
    W.chests["3,0,0"]={items={{name="minecraft:coal",count=64}}}
    navReady(); local supplies=require("supplies"); assert(supplies.prepare()); W.fuel=30
    assert(supplies.withFuelGoal(function() return 10000 end,function() return supplies.ensure({moves=10}) end))
    eq(W.fuel,W.limit-2); eq(W.x,0); eq(W.z,0)
end)
test("job fuel goal decreases with remaining work and ignores failed jobs", function()
    configured({fuel={x=0,y=0,z=0,direction=1,side="front"},output={x=0,y=0,z=0,direction=2,side="front"}})
    navReady()
    local p={total=1000,completed=0,remaining=1000,phase="mining"}
    require("telemetry").setProgress(p)
    local goal=assert(require("work_fuel").new("quarry",{x=2,y=0,z=0},{x=501,y=0,z=1}))
    local first=goal(); p.remaining,p.completed=100,900
    assert(goal()<first-1800)
    p.phase="failed"; eq(goal(),0)
end)
test("job fuel goal includes mandatory tunnel detours even with a shorter known route", function()
    configured({fuel={x=0,y=0,z=0,direction=1,side="front"},output={x=0,y=0,z=0,direction=2,side="front"}})
    navReady()
    require("telemetry").setProgress({total=20,completed=0,remaining=20,phase="mining"})
    local goal=assert(require("work_fuel").new("quarry",{x=2,y=0,z=0},{x=21,y=0,z=0}))
    local direct=goal()
    require("navigation").setRuntime(nil,nil,function(from,target)
        return math.abs(from.x-target.x)+math.abs(from.y-target.y)+math.abs(from.z-target.z)+100
    end)
    assert(goal()>=direct+400)
end)
test("job goal does not trigger early refuelling while the next action is safe", function()
    configured({fuel={x=0,y=0,z=0,direction=1,side="front"}})
    W.chests["1,0,0"]={items={{name="minecraft:coal",count=64}}}
    W.fuel=500; navReady(); local supplies=require("supplies"); assert(supplies.prepare())
    assert(supplies.withFuelGoal(function() return 10000 end,function() return supplies.ensure({moves=20}) end))
    eq(W.fuel,500); eq(#(W.refuelCounts or {}),0)
end)
test("job fuel goals are cleared on exceptions before another session", function()
    configured({fuel={x=0,y=0,z=0,direction=1,side="front"}})
    W.chests["1,0,0"]={items={{name="minecraft:coal",count=64}}}
    W.fuel=30; navReady(); local supplies=require("supplies"); assert(supplies.prepare())
    local ok,err=pcall(supplies.withFuelGoal,function() return 1000 end,function() error("test interruption") end)
    eq(ok,false); assert(tostring(err):find("test interruption",1,true))
    assert(supplies.ensure({moves=20})); assert(W.fuel<200)
end)
test("job accepts an available partial refill and does not loop on an empty chest", function()
    configured({fuel={x=0,y=0,z=0,direction=1,side="front"}})
    W.chests["1,0,0"]={items={{name="minecraft:coal",count=1}}}
    W.fuel=30; navReady(); local supplies=require("supplies"); assert(supplies.prepare())
    assert(supplies.withFuelGoal(function() return 1000 end,function() return supplies.ensure({moves=20}) end))
    eq(W.fuel,110)
    W.fuel=30; local stations=require("stations"); local original=stations.refuel; local visits=0
    stations.refuel=function(...) visits=visits+1; return original(...) end
    local ok,err=supplies.withFuelGoal(function() return 1000 end,function() return supplies.ensure({moves=20}) end)
    eq(ok,false); eq(err,"insufficient_fuel"); eq(visits,1)
end)

local function runSetup(answers)
    local originalPrint, originalWrite, originalRead = print, write, read
    local heading, reads, column = "not_called", 0, 0
    local prompts = {}
    package.loaded.navigation = {
        init = function(value) heading = value; return true end,
        getPosition = function() return { x = 0, y = 0, z = 0, direction = 1 } end,
        configure = function() end,
    }
    package.loaded.telemetry = { log = function() end }
    print = function(text) prompts[#prompts + 1] = tostring(text); column = 0 end
    write = function(text)
        -- Every input prompt must start on its own line and be short enough
        -- to leave room even on a narrow terminal.
        eq(column, 0); eq(text, "> "); column = #text
    end
    read = function()
        eq(column, 2)
        reads = reads + 1; column = 0
        assert(answers[reads] ~= nil, "unexpected question " .. reads)
        return answers[reads]
    end
    local ok, err = pcall(realLoadfile(ROOT .. "/turtle/setup.lua"))
    print, write, read = originalPrint, originalWrite, originalRead
    assert(ok, err); eq(reads, #answers)
    return heading, require("config").load(), table.concat(prompts, "\n")
end
test("setup accepts Ano without asking for manual heading", function()
    local heading, c = runSetup({ "Ano", "Ano", "Nie", "Nie", "Nie", "", "", "Nie", "" })
    eq(heading, nil); eq(c.home.direction, 1); eq(c.telemetry.enabled, false)
end)
test("setup accepts accented uppercase yes and letter choices", function()
    local heading = runSetup({ "  ÁNO  ", "Y", "N", "n", "n", "", "", "N", "" })
    eq(heading, nil)
end)
test("setup Enter defaults are consistent", function()
    local heading, c, prompts = runSetup({ "", "", "", "", "n", "", "", "n", "" })
    eq(heading, nil); eq(c.stations.materials, nil); eq(c.stations.output, nil)
    assert(prompts:find("Zistit smer automaticky cez GPS? [A/n]", 1, true))
    assert(prompts:find("Nastavit tuto stanicu? [a/N]", 1, true))
    assert(not prompts:find("1 = Ano", 1, true))
end)
test("setup accepts a and y interchangeably", function()
    local heading = runSetup({ "a", "y", "n", "n", "n", "", "", "n", "" })
    eq(heading, nil)
end)
test("setup invalid yes/no reprompts instead of silently selecting no", function()
    local heading = runSetup({ "maybe", "ano", "ano", "nie", "nie", "nie", "", "", "nie", "" })
    eq(heading, nil)
end)
test("setup explicit no selects manual heading", function()
    local heading = runSetup({ "Nie", "3", "ano", "nie", "nie", "nie", "", "", "nie", "" })
    eq(heading, 3)
end)

local function quarryWorld()
    configured({ fuel = { x = 0, y = 0, z = 0, direction = 3, side = "front" },
        output = { x = 0, y = 0, z = 0, direction = 0, side = "front" } })
    W.chests["-1,0,0"] = { items = { { name = "minecraft:coal", count = 64 } } }
    W.chests["0,0,-1"] = { items = {} }
    navReady()
end

test("cuboid sorts reversed corners and includes both endpoints", function()
    local b = assert(require("cuboid").new({ x = 4, y = 3, z = 2 }, { x = 2, y = 1, z = 1 }))
    eq(b.volume, 18); eq(b.size.x, 3); eq(b.min.y, 1); eq(b.max.z, 2)
end)
test("cuboid snakes cover all cells with adjacent layer transitions", function()
    local cuboid = require("cuboid")
    for x = 1, 4 do for y = 1, 3 do for z = 1, 4 do
        local b = assert(cuboid.new({ x = -2, y = -3, z = -4 }, { x = -3 + x, y = -4 + y, z = -5 + z }))
        for _, ex in ipairs({ b.min.x, b.max.x }) do for _, ez in ipairs({ b.min.z, b.max.z }) do
            local entry, seen, previous = { x = ex, y = b.max.y, z = ez }, {}, nil
            for index = 1, b.volume do
                local p = cuboid.cell(b, index, entry)
                assert(cuboid.contains(b, p)); assert(not seen[key(p)]); seen[key(p)] = true
                if previous then eq(require("pathfinding").distance(previous, p), 1) end
                previous = p
            end
        end end
    end end end
end)
test("quarry rejects station chest within mining bounds before movement", function()
    quarryWorld()
    local ok, err = require("mining").run({ x = -1, y = 0, z = 0 }, { x = -1, y = 0, z = 0 })
    eq(ok, false); eq(err, "station_inside_area:fuel"); eq(#W.digs, 0); eq(W.moves, 0)
end)
test("quarry mines reversed three dimensional corners and returns home", function()
    quarryWorld()
    local a, b = { x = 3, y = 0, z = 2 }, { x = 2, y = -1, z = 1 }
    for x = 2, 3 do for y = -1, 0 do for z = 1, 2 do W.blocks[key({ x = x, y = y, z = z })] = true end end end
    W.blocks["4,-1,2"] = true
    local ok, err, progress = require("mining").run(a, b)
    assert(ok, err); eq(progress.visited, 8); eq(progress.dug, 8)
    eq(progress.completed, 8); eq(progress.remaining, 0)
    eq(W.packets[#W.packets].progress.completed, 8)
    eq(W.packets[#W.packets].progress.phase, "complete")
    eq(W.digs[1].x, a.x); eq(W.digs[1].y, a.y); eq(W.digs[1].z, a.z)
    eq(W.x, 0); eq(W.y, 0); eq(W.z, 0); eq(W.d, 0); eq(W.blocks["4,-1,2"], true)
    eq(require("inventory").count("minecraft:cobblestone"), 0)
    local total = 0
    for _, item in ipairs(W.chests["0,0,-1"].items) do total = total + item.count end
    eq(total, 8); eq(W.lostDrops, 0)
end)
test("quarry unloads mid-job then resumes the correct cell", function()
    quarryWorld()
    local a, b = { x = 2, y = 0, z = 0 }, { x = 21, y = 0, z = 0 }
    for x = 2, 21 do
        local k = x .. ",0,0"; W.blocks[k] = true; W.drops[k] = "mod:item_" .. x
    end
    local ok, err, progress = require("mining").run(a, b)
    assert(ok, err); eq(progress.visited, 20); eq(#W.digs, 20); eq(W.lostDrops, 0)
    local total = 0
    for _, item in ipairs(W.chests["0,0,-1"].items) do total = total + item.count end
    eq(total, 20); eq(W.x, 0); eq(W.d, 0)
end)

test("550-cell quarry with 20000 fuel skips initial refuelling", function()
    quarryWorld(); W.fuel = 20000; W.limit = 40000
    local a, b = { x = 2, y = 0, z = 0 }, { x = 11, y = -4, z = 10 }
    for x = 2, 11 do for y = -4, 0 do for z = 0, 10 do
        W.blocks[x .. "," .. y .. "," .. z] = true
    end end end
    local ok, err, progress = require("mining").run(a, b)
    assert(ok, err); eq(progress.total, 550); eq(progress.completed, 550)
    assert(progress.startFuelRequired >= 1100 and progress.startFuelRequired < 20000)
    eq(#(W.refuelCounts or {}), 0); eq(W.chests["-1,0,0"].items[1].count, 64)
    assert(W.fuel < 20000); eq(W.x, 0); eq(W.y, 0); eq(W.z, 0)
end)

test("sufficient quarry fuel does not require coal in the fuel chest", function()
    quarryWorld(); W.chests["-1,0,0"].items = {}
    W.blocks["2,0,0"] = true
    local ok, err = require("mining").run({ x = 2, y = 0, z = 0 }, { x = 2, y = 0, z = 0 })
    assert(ok, err); eq(#(W.refuelCounts or {}), 0); eq(#W.digs, 1)
end)

test("small quarry refuels only to its doubled budget instead of the tank limit", function()
    quarryWorld(); W.fuel = 80; W.limit = 1000
    W.blocks["2,0,0"] = true
    local firstDigFuel
    local originalDig = turtle.dig
    turtle.dig = function(...)
        firstDigFuel = firstDigFuel or W.fuel
        return originalDig(...)
    end
    local ok, err, progress = require("mining").run({ x = 2, y = 0, z = 0 }, { x = 2, y = 0, z = 0 })
    assert(ok, err); assert(progress.startFuelRequired > 80)
    assert(#W.refuelCounts > 0); assert(W.fuel > 80)
    eq(progress.startFuelTarget, progress.startFuelRequired)
    assert(firstDigFuel >= progress.startFuelRequired - 5)
    assert(firstDigFuel < progress.startFuelRequired + 80)
    assert(firstDigFuel < W.limit - 80)
end)

test("quarry budget above tank capacity refuels up to capacity", function()
    quarryWorld(); W.fuel = 80; W.limit = 200
    W.blocks["2,0,0"] = true
    local firstDigFuel
    local originalDig = turtle.dig
    turtle.dig = function(...)
        firstDigFuel = firstDigFuel or W.fuel
        return originalDig(...)
    end
    local ok, err, progress = require("mining").run({ x = 2, y = 0, z = 0 }, { x = 2, y = 0, z = 0 })
    assert(ok, err); assert(progress.startFuelRequired > W.limit)
    eq(progress.startFuelTarget, W.limit)
    assert(firstDigFuel >= W.limit - 5); assert(firstDigFuel <= W.limit)
end)

test("capped quarry fuel budget includes travel back from a remote fuel chest", function()
    quarryWorld(); W.fuel = 80; W.limit = 200
    configured({ fuel = { x = 0, y = 0, z = -2, direction = 0, side = "front" },
        output = { x = 0, y = 0, z = 0, direction = 0, side = "front" } })
    W.chests["0,0,-3"] = { items = { { name = "minecraft:coal", count = 64 } } }
    W.blocks["2,0,0"] = true
    local ok, err, progress = require("mining").run({ x = 2, y = 0, z = 0 }, { x = 2, y = 0, z = 0 })
    assert(ok, err); assert(progress.startFuelRequired > W.limit)
    -- The output chest blocks the direct two-step route; verified detour is four.
    eq(progress.startFuelTarget, W.limit - 4)
    assert(#W.refuelCounts > 0); eq(W.x, 0); eq(W.z, 0)
end)
test("quarry unloads mined coal and returns with reserve", function()
    quarryWorld(); W.fuel = 200
    local a, b = { x = 2, y = 0, z = 0 }, { x = 20, y = 0, z = 0 }
    for x = 2, 20 do
        local k = x .. ",0,0"; W.blocks[k] = true; W.drops[k] = "minecraft:coal"
    end
    local ok, err = require("mining").run(a, b)
    assert(ok, err); eq(W.x, 0); eq(require("inventory").count("minecraft:coal"), 0)
    assert(W.fuel >= 20)
end)
test("quarry obtains chest fuel after excavation has started", function()
    quarryWorld(); W.fuel = 80; W.limit = 200
    local a, b = { x = 2, y = 0, z = 0 }, { x = 11, y = -2, z = 5 }
    for x = 2, 11 do for y = -2, 0 do for z = 0, 5 do
        W.blocks[x .. "," .. y .. "," .. z] = true
    end end end
    local ok, err, progress = require("mining").run(a, b)
    if not ok then
        for _, packet in ipairs(W.packets) do
            if packet.level == "error" then print(serialize(packet)) end
        end
    end
    assert(ok, err); eq(progress.visited, 180); assert(W.refuelAfterDig)
    assert(not W.chests["-1,0,0"].items[1] or W.chests["-1,0,0"].items[1].count < 64)
    eq(W.x, 0); eq(W.d, 0); eq(W.lostDrops, 0)
end)
test("quarry mid-job refuel covers remaining work instead of a few steps", function()
    quarryWorld(); W.limit = 40000; W.fuel = 20000
    local a, b = { x = 2, y = 0, z = 0 }, { x = 11, y = -1, z = 9 }
    for x = 2, 11 do for y = -1, 0 do for z = 0, 9 do
        W.blocks[x .. "," .. y .. "," .. z] = true
    end end end
    local nav, stations, c = require("navigation"), require("stations"), require("config").load()
    local dig, refill, visits = turtle.dig, stations.refuel, {}
    turtle.dig = function(...)
        local ok, err = dig(...)
        if #W.digs == 10 then W.fuel = nav.knownDistance(c.stations.fuel) + c.navigation.reserve + 5 end
        return ok, err
    end
    stations.refuel = function(target, options)
        local visit = { target = target, remaining = require("telemetry").getProgress().remaining }
        visits[#visits + 1] = visit
        local ok, err = refill(target, options); visit.fuel = W.fuel
        return ok, err
    end
    local ok, err, progress = require("mining").run(a, b)
    assert(ok, err); eq(progress.visited, 200); eq(#visits, 1)
    assert(visits[1].remaining > 100); assert(visits[1].target >= 2 * visits[1].remaining)
    assert(visits[1].fuel >= visits[1].target); assert(visits[1].fuel < W.limit)
    eq(W.x, 0); eq(W.y, 0); eq(W.z, 0)
end)
test("quarry unbreakable block stops without claiming completion", function()
    quarryWorld(); W.blocks["2,0,0"] = true; W.unbreakable["2,0,0"] = true
    local ok, err, progress = require("mining").run({ x = 2, y = 0, z = 0 }, { x = 2, y = 0, z = 0 })
    eq(ok, false); assert(err:find("dig_failed", 1, true)); eq(progress.visited, 0); eq(#W.digs, 0)
    eq(W.blocks["2,0,0"], true); eq(W.x, 0); eq(W.d, 0)
end)
test("quarry bounded falling block retries and accurate coordinates", function()
    quarryWorld(); W.blocks["2,0,0"] = true; W.falling["2,0,0"] = 2
    local ok, err, progress = require("mining").run({ x = 2, y = 0, z = 0 }, { x = 2, y = 0, z = 0 })
    assert(ok, err); eq(progress.dug, 3); eq(progress.visited, 1); eq(W.x, 0)
end)
test("quarry stops infinite falling blocks after its retry limit", function()
    quarryWorld(); W.blocks["2,0,0"] = true; W.falling["2,0,0"] = 100
    local ok, err, progress = require("mining").run({ x = 2, y = 0, z = 0 }, { x = 2, y = 0, z = 0 })
    eq(ok, false); eq(err, "dig_or_move_retry_limit"); eq(progress.visited, 0)
    eq(#W.digs, 32); eq(W.x, 0); eq(W.lostDrops, 0)
end)
test("quarry does not destroy unexpected inventory or fluids", function()
    quarryWorld(); W.chests["2,0,0"] = { items = {} }
    local mining = require("mining")
    local ok, err = mining.run({ x = 2, y = 0, z = 0 }, { x = 2, y = 0, z = 0 })
    eq(ok, false); eq(err, "inventory_in_area"); eq(#W.digs, 0)
    W.chests["2,0,0"] = nil; W.blockNames["2,0,0"] = "minecraft:lava"
    ok, err = mining.run({ x = 2, y = 0, z = 0 }, { x = 2, y = 0, z = 0 })
    eq(ok, false); eq(err, "fluid_in_area:minecraft:lava"); eq(#W.digs, 0)
end)
test("quarry waits for another turtle without digging it or abandoning work", function()
    quarryWorld(); W.x=1; navReady(); assert(require("supplies").prepare())
    W.blocks["2,0,0"]=true; W.blockNames["2,0,0"]="computercraft:turtle_advanced"
    local waits=0
    sleep=function(seconds)
        assert(seconds==0.5); waits=waits+1; eq(#W.digs,0); eq(W.x,1)
        if waits==3 then W.blocks["2,0,0"],W.blockNames["2,0,0"]=nil,nil end
    end
    local p={completed=0,total=1,dug=0}
    local box=assert(require("cuboid").new({x=2,y=0,z=0},{x=2,y=0,z=0}))
    local ok,err=require("mining").stepTo(box.min,box,p)
    assert(ok,err); eq(waits,3); eq(W.x,2); eq(#W.digs,0); eq(p.completed,1)
end)
test("waiting for another turtle remains cancellable", function()
    quarryWorld(); W.x=1; local nav=navReady(); assert(require("supplies").prepare())
    W.blocks["2,0,0"]=true; W.blockNames["2,0,0"]="computercraft:turtle_normal"
    local cancelled=false; sleep=function() cancelled=true end
    nav.setRuntime(nil,function() return not cancelled,"job_cancelled" end)
    local box=assert(require("cuboid").new({x=2,y=0,z=0},{x=2,y=0,z=0}))
    local ok,err=require("mining").stepTo(box.min,box,{dug=0})
    eq(ok,false); eq(err,"job_cancelled"); eq(W.x,1); eq(#W.digs,0)
end)
test("quarry retries its saved segment after water removal without double counting", function()
    quarryWorld(); W.fuel=1000
    local a,b={x=2,y=0,z=0},{x=5,y=0,z=0}
    for x=2,5 do W.blocks[x..",0,0"]=true end
    W.blockNames["4,0,0"]="minecraft:water"
    local mining=require("mining")
    local ok,err,p=mining.run(a,b)
    eq(ok,false); eq(err,"fluid_in_area:minecraft:water"); eq(p.visited,2); eq(p.dug,2)
    W.blocks["4,0,0"],W.blockNames["4,0,0"]=nil,nil
    local old=#W.digs
    local resumed,reason,progress=mining.run(a,b,nil,p)
    assert(resumed,reason); eq(progress.completed,4); eq(progress.remaining,0); eq(progress.dug,3)
    eq(#W.digs,old+1); eq(W.x,0); eq(W.y,0); eq(W.z,0)
end)
test("quarry full output chest preserves unfinished job and loot", function()
    quarryWorld(); W.chests["0,0,-1"].capacity = 0; W.blocks["2,0,0"] = true
    local ok, err, progress = require("mining").run({ x = 2, y = 0, z = 0 }, { x = 2, y = 0, z = 0 })
    eq(ok, false); eq(err, "output_chest_full"); eq(progress.phase, "failed")
    eq(require("inventory").count("minecraft:cobblestone"), 1); eq(W.lostDrops, 0)
end)
test("mining refuses digging outside the requested cuboid", function()
    quarryWorld(); W.blocks["1,0,0"] = true
    local box = assert(require("cuboid").new({ x = 2, y = 0, z = 0 }, { x = 3, y = 0, z = 0 }))
    local ok, err = require("mining").stepTo({ x = 1, y = 0, z = 0 }, box)
    eq(ok, false); eq(err, "dig_outside_area"); eq(#W.digs, 0); eq(W.moves, 0)
end)

test("quarry dialog accepts letter cancellation without moving", function()
    quarryWorld()
    local answers = { "2", "0", "0", "3", "1", "1", "n" }
    local originalPrint, originalWrite, originalRead = print, write, read
    local reads = 0
    print = function() end
    write = function(text) eq(text, "> ") end
    read = function() reads = reads + 1; assert(answers[reads], "unexpected question"); return answers[reads] end
    local ok, err = pcall(realLoadfile(ROOT .. "/turtle/quarry.lua"))
    print, write, read = originalPrint, originalWrite, originalRead
    assert(ok, err); eq(reads, 7); eq(W.moves, 0); eq(#W.digs, 0)
end)

test("fillFuel consumes sufficient coal from four stacks up to the actual limit", function()
    quarryWorld(); W.fuel = 237; W.limit = 20000
    W.chests["-1,0,0"].items = {}
    for _ = 1, 4 do W.chests["-1,0,0"].items[#W.chests["-1,0,0"].items + 1] = { name = "minecraft:coal", count = 64 } end
    assert(require("stations").fillFuel(require("supplies").navigationOptions() or {}))
    eq(W.fuel, 20000); eq(W.x, 0); eq(require("inventory").count("minecraft:coal"), 0)
    local left = 0
    for _, item in ipairs(W.chests["-1,0,0"].items) do left = left + item.count end
    eq(left, 8)
end)
test("fillFuel accepts an exhausted chest when partial fuel still permits return", function()
    quarryWorld(); W.fuel = 237; W.chests["-1,0,0"].items = { { name = "minecraft:coal", count = 2 } }
    assert(require("stations").fillFuel())
    eq(W.fuel, 397); eq(W.x, 0); eq(#W.chests["-1,0,0"].items, 0)
end)
test("fillFuel at a distant station does not request capacity beyond its tank", function()
    configured({ fuel = { x = 2, y = 0, z = 0, direction = 1, side = "front" } })
    W.chests["3,0,0"] = { items = { { name = "minecraft:coal", count = 64 } } }
    navReady()
    assert(require("stations").fillFuel())
    eq(W.fuel, W.limit - 2); eq(W.x, 0); eq(W.d, 0)
end)
test("reported coordinates dig below the turtle then connect to the FIRST corner", function()
    W.x, W.y, W.z = 7533, 68, -2505
    local c = require("config").defaults()
    c.start = { x = W.x, y = W.y, z = W.z, direction = 0 }
    c.home = c.start
    c.stations.fuel = { x = W.x, y = W.y, z = W.z, direction = 3, side = "front" }
    c.stations.output = { x = W.x, y = W.y, z = W.z, direction = 0, side = "front" }
    assert(require("config").save(c))
    W.chests["7532,68,-2505"] = { items = { { name = "minecraft:coal", count = 64 } } }
    W.chests["7533,68,-2506"] = { items = {} }
    for x = 7489, 7550 do for z = -2559, -2498 do W.blocks[x .. ",67," .. z] = true end end
    W.fuel = 237
    local nav = navReady()
    assert(require("supplies").prepare())
    local box = assert(require("mining").validateArea({ x = 7489, y = 67, z = -2498 }, { x = 7550, y = 60, z = -2559 }))
    eq(box.volume, 30752)
    local progress = { dug = 0 }
    local target, err = require("quarry_entry").enter(box, progress, function(p)
        local options = assert(require("supplies").navigationOptions())
        return nav.moveToCoord(p.x, p.y, p.z, options)
    end, require("mining").stepTo, function(target, box, progress)
        for _, axis in ipairs({ "x", "z" }) do
            while nav.getPosition()[axis] ~= target[axis] do
                local p = nav.getPosition()
                p[axis] = p[axis] + (target[axis] > p[axis] and 1 or -1)
                local ok, err = require("mining").stepTo(p, box, progress)
                if not ok then return false, err end
            end
        end
        return true
    end, { x = 7489, y = 67, z = -2498 })
    assert(target, err); eq(target.x, 7489); eq(target.y, 67); eq(target.z, -2498)
    eq(progress.dug, 52); eq(#progress.entryAttempts, 0); eq(W.moves, 52)
    eq(progress.localEntry.x, 7533); eq(progress.localEntry.z, -2505)
    matchesWorld(nav)
end)
test("quarry restores its work start after servicing and enters beneath itself", function()
    W.x, W.y, W.z = 3, 1, 1
    local c = configured({ fuel = { x = 0, y = 1, z = 1, direction = 3, side = "front" },
        output = { x = 0, y = 1, z = 1, direction = 0, side = "front" } })
    c.start = { x = 3, y = 1, z = 1, direction = 0 }; c.home = c.start
    assert(require("config").save(c))
    W.chests["-1,1,1"] = { items = { { name = "minecraft:coal", count = 64 } } }
    W.chests["0,1,0"] = { items = {} }
    navReady()
    local a, b = { x = 2, y = 0, z = 0 }, { x = 4, y = -1, z = 2 }
    local box = assert(require("cuboid").new(a, b))
    for x = 2, 4 do for y = -1, 0 do for z = 0, 2 do W.blocks[x .. "," .. y .. "," .. z] = true end end end
    -- All conventional external approaches to the first corner are blocked.
    for _, approach in ipairs(require("cuboid").approaches(box, require("navigation").getPosition(), a)) do
        W.blocks[key(approach.stand)] = true
    end
    local ok, err, progress = require("mining").run(a, b)
    assert(ok, err); eq(progress.visited, 18); eq(progress.dug, 18); eq(#progress.entryAttempts, 0)
    eq(W.digs[1].x, 3); eq(W.digs[1].y, 0); eq(W.digs[1].z, 1)
    for _, p in ipairs(W.digs) do assert(require("cuboid").contains(box, p)) end
    eq(W.x, 3); eq(W.y, 1); eq(W.z, 1); eq(W.d, 0)
end)
test("a lower first corner starts an ascending traversal without switching corners", function()
    quarryWorld()
    local a, b = { x = 3, y = -1, z = 2 }, { x = 2, y = 0, z = 1 }
    for x = 2, 3 do for y = -1, 0 do for z = 1, 2 do W.blocks[x .. "," .. y .. "," .. z] = true end end end
    local ok, err, progress = require("mining").run(a, b)
    assert(ok, err); eq(progress.visited, 8); eq(progress.dug, 8)
    eq(W.digs[1].x, 3); eq(W.digs[1].y, -1); eq(W.digs[1].z, 2)
    eq(W.x, 0); eq(W.y, 0); eq(W.z, 0)
end)
test("large known open quarry return route does not exhaust the node limit", function()
    local paths = require("pathfinding")
    for x = 7489, 7550 do for y = 60, 67 do for z = -2559, -2498 do
        paths.mark({ x = x, y = y, z = z }, true)
    end end end
    local route, err = paths.find({ x = 7489, y = 60, z = -2559 }, { x = 7550, y = 67, z = -2498 }, { knownOnly = true, maxNodes = 200 })
    assert(route, err); eq(#route, 129)
end)

test("quarry enters solid flat ground after a blocked side approach", function()
    quarryWorld()
    for x = 1, 5 do for z = -2, 3 do
        W.blocks[x .. ",0," .. z] = true
    end end
    local a, b = { x = 2, y = 0, z = 0 }, { x = 3, y = -1, z = 1 }
    for x = 2, 3 do for z = 0, 1 do W.blocks[x .. ",-1," .. z] = true end end
    local mining, cuboid = require("mining"), require("cuboid")
    local ok, err, progress = mining.run(a, b)
    assert(ok, err); eq(progress.visited, 8); assert(#progress.entryAttempts > 1)
    local box = assert(cuboid.new(a, b))
    for _, p in ipairs(W.digs) do assert(cuboid.contains(box, p)) end
    eq(W.blocks["1,0,0"], true); eq(W.blocks["4,0,0"], true); eq(W.x, 0)
end)
test("quarry uses side entrance when the upper approach is blocked", function()
    quarryWorld(); W.blocks["2,0,0"] = true; W.blocks["2,1,0"] = true
    local ok, err = require("mining").run({ x = 2, y = 0, z = 0 }, { x = 2, y = 0, z = 0 })
    assert(ok, err); eq(#W.digs, 1); eq(W.blocks["2,1,0"], true)
end)
test("all blocked entrances stop after the finite set without digging outside", function()
    quarryWorld()
    local cuboid = require("cuboid")
    local p = { x = 2, y = 0, z = 0 }
    local box = assert(cuboid.new(p, p))
    W.blocks[key(p)] = true
    local approaches = cuboid.approaches(box, require("navigation").getPosition(), p)
    eq(#approaches, 6)
    for _, a in ipairs(approaches) do W.blocks[key(a.stand)] = true end
    local ok, err, progress = require("mining").run(p, p)
    eq(ok, false); eq(err, "entry_unreachable:all_approaches_blocked")
    eq(#progress.entryAttempts, 6); eq(#W.digs, 0); eq(progress.visited, 0); eq(W.x, 0)
end)
test("entry does not retry a GPS or fuel failure at every corner", function()
    quarryWorld()
    local box = assert(require("cuboid").new({ x = 2, y = 0, z = 0 }, { x = 4, y = -1, z = 2 }))
    local attempts = 0
    local entry, err = require("quarry_entry").enter(box, {}, function()
        attempts = attempts + 1; return false, "gps_unavailable"
    end, function() error("must not dig") end, function() error("not inside") end)
    eq(entry, nil); eq(err, "entry_unreachable:gps_unavailable"); eq(attempts, 1)
end)

local function updaterEnvironment()
    local manifest = { version = 1, files = {
        { source = "fuel.lua", target = "fuel.lua", roles = { "turtle" } },
        { source = "receiver.lua", target = "receiver.lua", roles = { "receiver" } },
        { source = "network.lua", target = "network.lua", roles = { "turtle", "receiver" } },
    } }
    textutils.unserializeJSON = function(s)
        if s == "COMMIT" then return { sha = "abcdef123456" } end
        if s == "MANIFEST" then return manifest end
    end
    W.urls = {}
    http = { get = function(url)
        W.urls[#W.urls + 1] = url
        if W.downloadFail and url:match("network.lua$") then return nil, "network failure" end
        local content = url:match("/commits/main$") and "COMMIT"
            or (url:match("manifest.json$") and "MANIFEST" or "return { new = true }")
        return { readAll = function() return content end, close = function() end }
    end }
    W.files["fuel.lua"] = "return { old = true }"
    W.files["data/settings.txt"] = "user settings"
    return realLoadfile(ROOT .. "/turtle/turtle_update.lua")
end
test("updater pins version, selects role and preserves data", function()
    local update = updaterEnvironment()
    update("turtle")
    eq(W.files["fuel.lua"], "return { new = true }")
    eq(W.files["receiver.lua"], nil); eq(W.files["data/settings.txt"], "user settings")
    for i = 2, #W.urls do assert(W.urls[i]:find("/abcdef123456/turtle/", 1, true)) end
end)
test("failed download preserves all live files", function()
    local update = updaterEnvironment(); W.downloadFail = true
    eq(pcall(update, "turtle"), false)
    eq(W.files["fuel.lua"], "return { old = true }"); eq(W.files["network.lua"], nil)
end)
test("failed installation rolls back", function()
    local update = updaterEnvironment(); W.installFail = true
    eq(pcall(update, "turtle"), false)
    eq(W.files["fuel.lua"], "return { old = true }"); eq(W.files["network.lua"], nil)
    eq(W.files["data/update-journal.txt"], nil)
end)
test("interrupted update restores before downloading", function()
    local update = updaterEnvironment()
    W.files["data/update-backup/fuel.lua"] = "return { original = true }"
    W.files["data/update-journal.txt"] = serialize({ { target = "fuel.lua", existed = true } })
    W.files["fuel.lua"] = "broken"; W.downloadFail = true
    eq(pcall(update, "turtle"), false)
    eq(W.files["fuel.lua"], "return { original = true }")
end)
realLoadfile(ROOT .. "/tests/fleet_spec.lua")({ test = test, eq = eq,
    world = function() return W end, configured = configured, navReady = navReady })
realLoadfile(ROOT .. "/tests/floor_spec.lua")({ test = test, eq = eq,
    world = function() return W end, configured = configured, navReady = navReady })
print("All " .. tests .. " regression tests passed.")
