"""Oltar event-loop tests with mocked CC: Tweaked peripherals (requires Lupa)."""
from pathlib import Path
import json
import sys

root = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root / ".dev-runtime"))
from lupa.lua52 import LuaRuntime

lua = LuaRuntime(unpack_returned_tuples=True)
lua.globals().ROOT = root.as_posix()
lua.execute(r'''
local protocol = "oltar.v2"
local function eq(actual, expected)
    assert(actual == expected, "expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function harness(program, front, back, config)
    local h = { inputs = { front = front or false, back = back or 1 },
        outputs = {}, frequencies = {}, sent = {}, actions = {}, errors = {}, queries = 0 }
    local env = setmetatable({}, { __index = _G })
    env.print = function() end
    env.printError = function(err) h.errors[#h.errors + 1] = err end
    env.write = function() end
    env.read = function() return table.remove(h.answers, 1) end
    env.redstone = {
        getInput = function(side) return h.inputs[side] or false end,
        getAnalogInput = function(side) return h.inputs[side] or 0 end,
        setOutput = function(side, state)
            h.outputs[side] = state
            h.actions[#h.actions + 1] = { side, state }
        end,
        setAnalogOutput = function(side, strength)
            h.outputs[side] = strength
            h.actions[#h.actions + 1] = { side, strength }
        end,
    }
    local teleporter = { setFrequency = function(name)
        if h.failFrequency then error("Frequency unavailable") end
        h.frequencies[#h.frequencies + 1] = name
        if not h.ignoreFrequency then h.actualFrequency = name end
        if h.dropFrontOnFrequency then h.inputs.front = false end
    end,
        getFrequency = function() return { key = h.actualFrequency } end,
    }
    env.peripheral = {
        getNames = function() return h.noModem and {} or { "top" } end,
        hasType = function(_, kind) return kind == "modem" end,
        wrap = function(side)
            eq(side, "back")
            if h.detached then return nil end
            return teleporter
        end,
    }
    env.rednet = {
        open = function(side) eq(side, "top") end,
        broadcast = function(message, p) eq(p, protocol); eq(message.kind, "query"); h.queries = h.queries + 1 end,
        send = function(id, message, p)
            eq(p, protocol)
            h.sent[#h.sent + 1] = { id = id, name = message.name, count = message.count, signal = message.signal, capacity = message.capacity }
            h.actions[#h.actions + 1] = { "send", message.count }
        end,
    }
    env.os = {
        getComputerID = function() return program == "main" and 99 or 13 end,
        startTimer = function(seconds)
            assert(seconds == 2 or seconds == 0.25)
            h.timer = (h.timer or 0) + 1
            if seconds == 2 then h.networkTimer = h.timer else h.inputTimer = h.timer end
            return h.timer
        end,
        pullEvent = function()
            local event = { coroutine.yield() }
            if event[1] == "terminate" then error("Terminated", 0) end
            return table.unpack(event)
        end,
    }
    env.shell = { getRunningProgram = function() return "oltar/client.lua" end,
        run = function(name) h.routerProgram = name end }
    h.config = config
    h.mainConfig = "target:15"
    env.fs = {
        getDir = function() return "oltar" end,
        combine = function(a, b) return a .. "/" .. b end,
        exists = function(path) return (path:find("main-config", 1, true) and h.mainConfig or h.config) ~= nil end,
        open = function(path, mode)
            return {
                readAll = function() return path:find("main-config", 1, true) and h.mainConfig or h.config end,
                write = function(value)
                    if path:find("main-config", 1, true) then h.mainConfig = value else h.config = value end
                end,
                close = function() end,
            }
        end,
    }
    env.textutils = {
        serialize = function(c)
            if c.targetCount then return "target:" .. c.targetCount end
            return c.name .. "," .. c.mainId .. "," .. c.emptySignal
        end,
        unserialize = function(value)
            if value:match("^target:") then return { targetCount = tonumber(value:match("%d+")) } end
            local name, id, empty = value:match("^(oltar_%d),(%d+),?(%d*)$")
            return { name = name, mainId = tonumber(id), emptySignal = tonumber(empty) }
        end,
    }
    local source = assert(io.open(ROOT .. "/oltar/" .. program .. ".lua", "r"))
    local code = source:read("*a"); source:close()
    h.co = coroutine.create(assert(load(code, program, "t", env)))
    function h.step(...)
        local ok, err = coroutine.resume(h.co, ...)
        assert(ok, err)
    end
    function h.state(index, count, sender, capacity)
        h.step("rednet_message", sender or (10 + index),
            { kind = "state", name = "oltar_" .. index, count = count, capacity = capacity or 15 }, protocol)
    end
    return h
end

local function ready(h, counts)
    for i = 1, 4 do h.state(i, counts and counts[i] or 0) end
end
local h = harness("main", true)
h.step()
eq(h.frequencies[1], "oltar_1"); eq(h.outputs.right, false)
h.state(2, 0); h.state(1, 0); h.state(3, 0)
eq(h.outputs.right, false) -- Wait for the fourth counting sensor.
h.state(4, 0); eq(h.outputs.right, true)
for round = 1, 5 do
    for i = 1, 4 do
        eq(h.actualFrequency, "oltar_" .. i)
        h.state(i, round)
    end
end
eq(h.outputs.right, false)
-- At the limit, a missing mob is replaced in exactly the affected tower.
h.state(3, 4); eq(h.actualFrequency, "oltar_3"); eq(h.outputs.right, true)
h.state(3, 5); eq(h.outputs.right, false)
-- Lower counts have priority; ties go in order 1,2,3,4.
h.state(2, 2); h.state(1, 3); eq(h.actualFrequency, "oltar_2")
h.state(2, 3); eq(h.actualFrequency, "oltar_1")
h.inputs.front = false; h.step("redstone"); eq(h.outputs.right, false)
local n = #h.frequencies
h.state(4, 1); eq(#h.frequencies, n)
h.inputs.front = true; h.step("redstone"); eq(h.actualFrequency, "oltar_4")
h.state(4, 14, 77); eq(h.actualFrequency, "oltar_4")
for _, message in ipairs({
    { kind = "state", name = "oltar_4", count = "14", capacity = 14 },
    { kind = "state", name = "oltar_4", count = 1.5, capacity = 14 },
    { kind = "state", name = "oltar_4", count = 15, capacity = 14 },
    { kind = "state", name = "oltar_4", active = true },
}) do h.step("rednet_message", 14, message, protocol) end
eq(h.actualFrequency, "oltar_4")
h.step("rednet_message", 14, { kind = "state", name = "oltar_4", count = 14, capacity = 14 }, "oltar.v1")
eq(h.actualFrequency, "oltar_4")
h.step("timer", h.networkTimer); eq(h.queries, 2)
h.step("terminate"); eq(h.outputs.right, false)

h = harness("main", true); h.answers = { "0", "2" }; h.step("setup")
eq(h.mainConfig, "target:2"); ready(h)
for round = 1, 2 do for i = 1, 4 do h.state(i, round) end end
eq(h.outputs.right, false)
h.state(3, 1); eq(h.actualFrequency, "oltar_3"); eq(h.outputs.right, true)
h.failFrequency = true; h.state(1, 0); eq(h.outputs.right, false); eq(#h.errors, 1)
h.failFrequency = false; h.step("timer", h.inputTimer); eq(h.actualFrequency, "oltar_1")
h.ignoreFrequency = true; h.state(1, 2)
eq(h.outputs.right, false); eq(h.actualFrequency, "oltar_1")
h.ignoreFrequency = false; h.step("timer", h.inputTimer)
eq(h.actualFrequency, "oltar_3"); eq(h.outputs.right, true)
h.actualFrequency = "oltar_4"; h.step("timer", h.inputTimer); eq(h.actualFrequency, "oltar_3")
h.step("peripheral_detach", "back"); eq(h.outputs.right, false)
h.step("peripheral", "back"); eq(h.outputs.right, true)
h.inputs.front = false; h.step("timer", h.inputTimer); eq(h.outputs.right, false)
h.inputs.front = true; h.step("timer", h.inputTimer); eq(h.outputs.right, true)
h.step("terminate")

h = harness("main", false); h.failFrequency = true; h.step()
eq(coroutine.status(h.co), "suspended"); eq(h.outputs.right, false)
ready(h); h.inputs.front = true; h.step("redstone"); eq(h.outputs.right, false)
h.failFrequency = false; h.step("timer", h.inputTimer); eq(h.outputs.right, true)
h.dropFrontOnFrequency = true; h.state(1, 1); eq(h.outputs.right, false)
h.step("terminate")
-- The sensor's representable capacity limits any larger configured goal.
h = harness("main", true); h.step()
for i = 1, 4 do h.state(i, 3, nil, 3) end
eq(h.outputs.right, false); h.step("terminate")

-- Migrate the old client config without changing identity or main ID.
h = harness("client", false, 0, "oltar_3,99"); h.step()
eq(h.config, "oltar_3,99,0")
eq(h.sent[1].name, "oltar_3"); eq(h.sent[1].id, 99)
eq(h.sent[1].signal, 0); eq(h.sent[1].count, 0); eq(h.outputs.bottom, false)
eq(h.outputs.right, 0)
h.inputs.back = 1; h.step("redstone")
eq(h.sent[2].count, 1); eq(h.outputs.bottom, true)
eq(h.outputs.right, 15)
eq(h.actions[#h.actions-1][1], "send") -- Send before enabling bottom.
h.inputs.back = 2; h.step("redstone")
eq(h.sent[3].count, 2); eq(h.outputs.bottom, true) -- Boolean input stayed true.
eq(h.outputs.right, 15)
h.inputs.back = 15; h.step("timer", h.inputTimer)
eq(h.sent[4].count, 15); eq(h.sent[4].capacity, 15)
eq(h.outputs.right, 15)
h.inputs.back = 0; h.step("redstone")
eq(h.sent[5].count, 0); eq(h.outputs.bottom, false)
eq(h.outputs.right, 0)
eq(h.actions[#h.actions-2][1], "bottom") -- Disable bottom before sending zero.
h.step("redstone"); eq(#h.sent, 5)
h.step("timer", h.networkTimer); eq(#h.sent, 6)
h.step("rednet_message", 99, { kind = "query" }, protocol); eq(#h.sent, 7)
h.step("rednet_message", 42, { kind = "query" }, protocol); eq(#h.sent, 7)
h.inputs.back = 1; h.step("redstone"); eq(h.sent[8].count, 1)
h.step("terminate"); eq(h.outputs.bottom, false); eq(h.outputs.right, 0)

h = harness("client", false, 0)
h.answers = { "5", "99", "1", "99" }; h.step()
eq(h.config, "oltar_1,99,0"); eq(h.sent[1].count, 0)
h.step("terminate")
h = harness("client", false, 2, "oltar_1,99")
h.answers = { "4", "99", "0" }; h.step("setup")
eq(h.config, "oltar_4,99,0"); eq(h.sent[1].count, 2); eq(h.sent[1].capacity, 15)
h.step("terminate")
-- Preserve a previously calibrated baseline until explicitly reconfigured.
h = harness("client", false, 2, "oltar_1,99,1"); h.step()
eq(h.config, "oltar_1,99,1"); eq(h.sent[1].count, 1)
h.inputs.back = 1; h.step("redstone")
eq(h.sent[#h.sent].count, 0); eq(h.outputs.bottom, false); eq(h.outputs.right, 15)
h.step("terminate")
eq(h.outputs.right, 0)
h = harness("main", true); h.mainConfig = nil; h.step()
eq(h.mainConfig, "target:5"); h.step("terminate")
h = harness("main", true); h.mainConfig = "target:14"; h.step()
eq(h.mainConfig, "target:5"); h.step("terminate")
h = harness("client", false, 2, "oltar_1,99"); h.noModem = true; h.step()
eq(h.outputs.bottom, false); eq(#h.errors, 1)
eq(h.outputs.right, 0)
h = harness("main", true); h.step(); eq(h.mainConfig, "target:5")
ready(h, { 5, 6, 7, 8 }); eq(h.outputs.right, false)
h.state(3, 4); eq(h.outputs.right, true); eq(h.actualFrequency, "oltar_3")
h.state(3, 6); eq(h.outputs.right, false); h.step("terminate")
h = harness("main", true); h.mainConfig = "target:3"; h.step()
eq(h.mainConfig, "target:3"); ready(h, {3,3,3,3}); eq(h.outputs.right, false)
h.step("terminate")
h = harness("router"); h.step(); eq(h.routerProgram, "repeat")
print("Oltar OK: analog counts, 5 rounds, refill, configured limits, stop/resume, validation, teleporter recovery, config migration.")
''')

manifest = json.loads((root / "oltar/manifest.json").read_text(encoding="utf-8"))
def to_lua(value):
    if isinstance(value, dict):
        return lua.table_from({key: to_lua(item) for key, item in value.items()})
    if isinstance(value, list):
        return lua.table_from([to_lua(item) for item in value])
    return value

lua.globals().MANIFEST = to_lua(manifest)
lua.globals().SOURCES = lua.table_from({
    path.name: path.read_text(encoding="utf-8") for path in (root / "oltar").glob("*.lua")
})
for role in ("main", "client", "router"):
    entries = [entry for entry in manifest["files"] if role in entry["roles"]]
    assert {entry["target"] for entry in entries} == {"update.lua", "startup.lua", role + ".lua"}
assert {entry["source"] for entry in manifest["files"]} == set(lua.globals().SOURCES.keys())

lua.execute(r'''
local function eq(a, b) assert(a == b, tostring(a) .. " ~= " .. tostring(b)) end
local function installer()
    local h = { files = { ["client-config.txt"] = "saved client settings" }, dirs = {},
        urls = {}, serialized = {}, nextSerial = 0, answers = {} }
    local env = setmetatable({}, { __index = _G })
    env.print = function() end
    env.printError = function(err) h.error = err end
    env.write = function() end
    env.read = function() return table.remove(h.answers, 1) end
    local function exists(path) return h.files[path] ~= nil or h.dirs[path] == true end
    env.fs = {
        exists = exists,
        makeDir = function(path) h.dirs[path] = true end,
        combine = function(a, b) return a == "" and b or a .. "/" .. b end,
        getDir = function() return "" end,
        delete = function(path)
            h.files[path] = nil; h.dirs[path] = nil
            for name in pairs(h.files) do
                if name:sub(1, #path + 1) == path .. "/" then h.files[name] = nil end
            end
            for name in pairs(h.dirs) do
                if name:sub(1, #path + 1) == path .. "/" then h.dirs[name] = nil end
            end
        end,
        copy = function(a, b) assert(h.files[a]); h.files[b] = h.files[a] end,
        move = function(a, b)
            if h.failMove == b then h.failMove = nil; error("Disk failure") end
            assert(h.files[a]); h.files[b] = h.files[a]; h.files[a] = nil
        end,
        open = function(path, mode)
            if mode == "r" and not h.files[path] then return nil end
            if mode == "w" then h.files[path] = "" end
            return {
                readAll = function() return h.files[path] end,
                write = function(value) h.files[path] = h.files[path] .. value end,
                close = function() end,
            }
        end,
    }
    env.textutils = {
        unserializeJSON = function(contents)
            if contents == "commit" then return { sha = "abcdef123456" } end
            eq(contents, "manifest"); return MANIFEST
        end,
        serialize = function(value)
            h.nextSerial = h.nextSerial + 1
            local key = "serialized:" .. h.nextSerial
            h.serialized[key] = value; return key
        end,
        unserialize = function(key) return h.serialized[key] end,
    }
    env.http = { get = function(url)
        h.urls[#h.urls + 1] = url
        local name = url:match("/([^/]+)$")
        if h.failDownload == name then return nil, "Offline" end
        local contents
        if url:find("api.github.com", 1, true) then contents = "commit"
        elseif name == "manifest.json" then contents = "manifest"
        else
            assert(url:find("/abcdef123456/oltar/", 1, true), "Download must use resolved commit")
            contents = SOURCES[name]
        end
        if name == h.invalidSyntax then contents = "local = broken" end
        assert(contents, url)
        return { readAll = function() return contents end, close = function() end }
    end }
    env.shell = {
        getRunningProgram = function() return "startup.lua" end,
        run = function(program) h.started = program; return true end,
    }
    function h.update(role)
        return pcall(assert(load(SOURCES["oltar_update.lua"], "update", "t", env)), role)
    end
    function h.boot(arg)
        assert(load(SOURCES["startup.lua"], "startup", "t", env))(arg)
    end
    h.serialize = env.textutils.serialize
    return h
end

for _, role in ipairs({ "main", "client", "router" }) do
    local h = installer()
    assert(h.update(role))
    eq(h.files["oltar-role.txt"], role)
    eq(h.files[role .. ".lua"], SOURCES[role .. ".lua"])
    eq(h.files["startup.lua"], SOURCES["startup.lua"])
    eq(h.files["update.lua"], SOURCES["oltar_update.lua"])
    eq(h.files["client-config.txt"], "saved client settings")
    h.boot(); eq(h.started, role .. ".lua")
    assert(h.update()); eq(h.files["oltar-role.txt"], role)
end

-- A failed download or syntax check never changes installed files or role.
for _, fault in ipairs({ "download", "syntax", "move" }) do
    local h = installer()
    h.files["oltar-role.txt"] = "main"
    h.files["startup.lua"] = "old startup"
    h.files["update.lua"] = "old updater"
    if fault == "download" then h.failDownload = "client.lua"
    elseif fault == "syntax" then h.invalidSyntax = "client.lua"
    else h.failMove = "oltar-role.txt" end
    local ok = h.update("client"); eq(ok, false)
    eq(h.files["oltar-role.txt"], "main")
    eq(h.files["startup.lua"], "old startup")
    eq(h.files["update.lua"], "old updater")
    eq(h.files["client.lua"], nil)
    eq(h.files["client-config.txt"], "saved client settings")
end

-- Recover the role before deciding which role a no-argument update installs.
local h = installer()
h.files["oltar-role.txt"] = "client"
h.files["data/oltar-update-backup/oltar-role.txt"] = "main"
h.files["data/oltar-update-journal.txt"] = h.serialize({ { target = "oltar-role.txt", existed = true } })
assert(h.update()); eq(h.files["oltar-role.txt"], "main"); assert(h.files["main.lua"])
eq(h.files["data/oltar-update-journal.txt"], nil)

h = installer(); eq(h.update("invalid"), false)
eq(#h.urls, 0); eq(h.files["startup.lua"], nil)
h.files["client.lua"] = SOURCES["client.lua"]
h.answers = { "invalid", "client" }; h.boot()
eq(h.files["oltar-role.txt"], "client"); eq(h.started, "client.lua")
h.started = nil; h.boot(); eq(h.started, "client.lua")
h.files["router.lua"] = SOURCES["router.lua"]
h.answers = { "router" }; h.boot("setup")
eq(h.files["oltar-role.txt"], "router"); eq(h.started, "router.lua")
h.files["router.lua"] = nil; h.started = nil; h.boot()
eq(h.started, nil); assert(h.error:find("router.lua", 1, true))
print("Oltar update/startup OK: all roles, saved settings, failed download/syntax/install, recovery, boot setup.")
''')
