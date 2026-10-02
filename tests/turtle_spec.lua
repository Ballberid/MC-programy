package.path = ROOT .. "/turtle/?.lua;" .. package.path
local realLoadfile = loadfile
local modules = { "config", "fuel", "inventory", "position", "pathfinding", "navigation", "stations", "supplies", "network", "telemetry" }
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
local function serialize(t)
    if type(t) == "string" then return string.format("%q", t) end
    if type(t) ~= "table" then return tostring(t) end
    local parts = {}
    for k, v in pairs(t) do parts[#parts + 1] = "[" .. serialize(k) .. "]=" .. serialize(v) end
    return "{" .. table.concat(parts, ",") .. "}"
end
local function reset()
    for _, name in ipairs(modules) do package.loaded[name] = nil end
    W = { x = 0, y = 0, z = 0, d = 0, fuel = 1000, limit = 2000,
        blocks = {}, chests = {}, slots = {}, selected = 1, moves = 0, gpsCalls = 0,
        files = {}, dirs = {}, packets = {}, failSteps = 0, ticks = 0 }
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
        local amount = math.min(count or i.count, i.count)
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
test("fuel station visit refuels and returns", function()
    configured({ fuel = { x = 2, y = 0, z = 0, direction = 1, side = "front" } })
    W.chests["3,0,0"] = { items = { { name = "minecraft:coal", count = 16 } } }
    W.fuel = 100
    local nav = navReady()
    assert(require("stations").refuel(500))
    eq(W.x, 0); eq(W.d, 0); assert(W.fuel >= 500); matchesWorld(nav)
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
    for _, line in ipairs(lines) do assert(not line:find("fake", 1, true)) end
end)
test("read-only diagnostics do not move or consume items", function()
    configured()
    W.slots[1] = { name = "minecraft:coal", count = 10 }
    realLoadfile(ROOT .. "/turtle/test.lua")("check")
    eq(W.moves, 0); eq(W.slots[1].count, 10); eq(W.fuel, 1000)
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
print("All " .. tests .. " regression tests passed.")
