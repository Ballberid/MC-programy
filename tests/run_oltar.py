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
local protocol = "oltar.v1"
local function eq(actual, expected)
    assert(actual == expected, "expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function harness(program, front, back, config)
    local h = { inputs = { front = front or false, back = back or false },
        outputs = {}, frequencies = {}, sent = {}, actions = {}, errors = {}, queries = 0 }
    local env = setmetatable({}, { __index = _G })
    env.print = function() end
    env.printError = function(err) h.errors[#h.errors + 1] = err end
    env.write = function() end
    env.read = function() return table.remove(h.answers, 1) end
    env.redstone = {
        getInput = function(side) return h.inputs[side] or false end,
        setOutput = function(side, state)
            h.outputs[side] = state
            h.actions[#h.actions + 1] = { side, state }
        end,
    }
    local teleporter = { setFrequency = function(name)
        if h.failFrequency then error("Frequency unavailable") end
        h.frequencies[#h.frequencies + 1] = name
        if h.dropFrontOnFrequency then h.inputs.front = false end
    end }
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
            h.sent[#h.sent + 1] = { id = id, name = message.name, active = message.active }
            h.actions[#h.actions + 1] = { "send", message.active }
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
    env.fs = {
        getDir = function() return "oltar" end,
        combine = function(a, b) return a .. "/" .. b end,
        exists = function() return h.config ~= nil end,
        open = function(_, mode)
            return {
                readAll = function() return h.config end,
                write = function(value) h.config = value end,
                close = function() end,
            }
        end,
    }
    env.textutils = {
        serialize = function(c) return c.name .. "," .. c.mainId end,
        unserialize = function(value)
            local name, id = value:match("^(oltar_%d),(%d+)$")
            return { name = name, mainId = tonumber(id) }
        end,
    }
    local source = assert(io.open(ROOT .. "/oltar/" .. program .. ".lua", "r"))
    local code = source:read("*a"); source:close()
    h.co = coroutine.create(assert(load(code, program, "t", env)))
    function h.step(...)
        local ok, err = coroutine.resume(h.co, ...)
        assert(ok, err)
    end
    function h.state(index, active, sender)
        h.step("rednet_message", sender or (10 + index),
            { kind = "state", name = "oltar_" .. index, active = active }, protocol)
    end
    return h
end

local h = harness("main", true)
h.step()
eq(h.frequencies[1], "oltar_1"); eq(h.outputs.left, true)
h.state(2, true) -- Out-of-order messages must not skip the first empty altar.
eq(#h.frequencies, 1)
h.state(1, true); eq(h.frequencies[#h.frequencies], "oltar_3")
h.state(3, true); eq(h.frequencies[#h.frequencies], "oltar_4")
h.state(4, true); eq(h.outputs.left, false)
h.state(3, false); eq(h.frequencies[#h.frequencies], "oltar_3"); eq(h.outputs.left, true)
h.state(1, false); eq(h.frequencies[#h.frequencies], "oltar_1")
h.state(1, true); eq(h.frequencies[#h.frequencies], "oltar_3")
h.inputs.front = false; h.step("redstone"); eq(h.outputs.left, false)
local count = #h.frequencies
h.state(2, false); eq(#h.frequencies, count); eq(h.outputs.left, false)
h.inputs.front = true; h.step("redstone")
eq(h.frequencies[#h.frequencies], "oltar_2"); eq(h.outputs.left, true)
h.state(2, true, 77) -- Duplicate name on a different PC is rejected.
eq(h.frequencies[#h.frequencies], "oltar_2")
h.step("rednet_message", 12, { kind = "state", name = "oltar_2", active = "true" }, protocol)
eq(h.frequencies[#h.frequencies], "oltar_2")
h.step("rednet_message", 12, { kind = "state", name = "oltar_2", active = true }, "other")
eq(h.frequencies[#h.frequencies], "oltar_2")
h.state(2, true); h.state(3, true); eq(h.outputs.left, false)
h.step("timer", h.networkTimer); eq(h.queries, 2); eq(h.outputs.left, false)
h.step("terminate"); eq(h.outputs.left, false)

-- Normal startup order 1 -> 2 -> 3 -> 4, then refill only the third.
h = harness("main", true); h.step()
for i = 1, 4 do h.state(i, true) end
eq(table.concat(h.frequencies, ","), "oltar_1,oltar_2,oltar_3,oltar_4")
eq(h.outputs.left, false)
h.state(3, false); eq(h.frequencies[5], "oltar_3"); eq(h.outputs.left, true)
h.failFrequency = true; h.state(1, false)
eq(h.outputs.left, false); eq(#h.errors, 1)
h.inputs.front = false; h.step("redstone"); eq(h.outputs.left, false)
h.failFrequency = false; h.inputs.front = true
h.step("timer", h.inputTimer)
eq(h.outputs.left, true); eq(h.frequencies[#h.frequencies], "oltar_1")
h.step("terminate")

h = harness("main", false); h.step()
eq(h.frequencies[1], "oltar_1"); eq(h.outputs.left, false)
h.state(1, true); eq(#h.frequencies, 1)
h.inputs.front = true; h.step("redstone"); eq(h.frequencies[2], "oltar_2")
h.step("peripheral_detach", "back"); eq(h.outputs.left, false); eq(#h.errors, 1)
h.step("peripheral", "back"); eq(h.outputs.left, true)
h.inputs.front = false; h.step("timer", h.inputTimer); eq(h.outputs.left, false)
h.inputs.front = true; h.step("timer", h.inputTimer); eq(h.outputs.left, true)
h.step("terminate")

h = harness("main", false); h.failFrequency = true; h.step()
eq(coroutine.status(h.co), "suspended"); eq(h.outputs.left, false)
h.inputs.front = true; h.step("redstone"); eq(h.outputs.left, false)
h.failFrequency = false; h.step("timer", h.inputTimer); eq(h.outputs.left, true)
h.dropFrontOnFrequency = true; h.state(1, true); eq(h.outputs.left, false)
h.step("terminate")

h = harness("client", false, true, "oltar_3,99"); h.step()
eq(h.sent[1].name, "oltar_3"); eq(h.sent[1].id, 99); eq(h.sent[1].active, true)
eq(h.actions[2][1], "send"); eq(h.actions[3][1], "bottom"); eq(h.actions[3][2], true)
h.inputs.back = false; h.step("redstone")
eq(h.actions[4][1], "bottom"); eq(h.actions[4][2], false)
eq(h.actions[5][1], "send"); eq(h.sent[2].active, false); eq(h.outputs.bottom, false)
h.step("redstone"); eq(#h.sent, 2)
h.step("timer", h.timer); eq(#h.sent, 3)
h.step("rednet_message", 99, { kind = "query" }, protocol); eq(#h.sent, 4)
h.step("rednet_message", 42, { kind = "query" }, protocol); eq(#h.sent, 4)
h.inputs.back = true; h.step("redstone"); eq(h.outputs.bottom, true)
h.step("terminate"); eq(h.outputs.bottom, false)

h = harness("client", false, false)
h.answers = { "5", "99", "1", "99" }; h.step()
eq(h.config, "oltar_1,99"); eq(h.sent[1].active, false); eq(h.outputs.bottom, false)
h.step("terminate")
h = harness("client", false, false, "oltar_1,99")
h.answers = { "4", "99" }; h.step("setup")
eq(h.config, "oltar_4,99"); eq(h.sent[1].name, "oltar_4")
h.step("terminate")
h = harness("client", false, true, "oltar_1,99"); h.noModem = true; h.step()
eq(h.outputs.bottom, false); eq(#h.errors, 1)
h = harness("router"); h.step(); eq(h.routerProgram, "repeat")
print("Oltar OK: main sequencing, refill, stop/resume, validation, cleanup, client setup/reporting, router.")
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
