-- Run on a computer or CC pocket computer: receiver [turtleID] [protocol]
local network = require("network")
local args = { ... }
local filter = args[1] and tonumber(args[1])
if args[1] and not filter then error("Pouzitie: receiver [turtleID] [protocol]", 0) end
local protocol = args[2] or "craftoria.turtle.v1"
local ok, err = network.open()
if not ok then error("Pripoj modem: " .. tostring(err), 0) end
local screen = peripheral.find("monitor") or term.current()
if screen.setTextScale then screen.setTextScale(0.5) end
local devices = {}
local lastMessage = "Cakam na telemetriu..."

local function safe(value, max)
    return tostring(value or "?"):gsub("[%c]", " "):sub(1, max or 160)
end

local function draw()
    screen.clear()
    local width, height = screen.getSize()
    local line = 1
    local function out(text)
        if line > height then return end
        screen.setCursorPos(1, line)
        screen.write(safe(text, width)); line = line + 1
    end
    out("Craftoria / " .. protocol)
    out(lastMessage)
    local ids = {}
    for id in pairs(devices) do ids[#ids + 1] = id end
    table.sort(ids)
    for _, id in ipairs(ids) do
        local entry = devices[id]
        local p = entry.packet
        local age = math.floor(os.clock() - entry.received)
        out("#" .. id .. " " .. safe(p.label, 30) .. " (" .. age .. "s od spravy)")
        out("Stav: " .. safe(p.activity) .. " | " .. safe(p.level))
        local pos = p.position
        if type(pos) == "table" then
            out("XYZ: " .. safe(pos.x) .. "," .. safe(pos.y) .. "," .. safe(pos.z) .. " dir=" .. safe(pos.direction))
        end
        local inventory = type(p.inventory) == "table" and p.inventory or {}
        out("Palivo: " .. safe(p.fuel) .. " | Volne sloty: " .. safe(inventory.freeSlots))
        out(safe(p.message))
        out("----------------")
    end
end

local function valid(p, sender)
    return type(p) == "table" and p.version == 1 and p.id == sender
        and type(p.message) == "string" and #p.message <= 4096
        and (p.position == nil or type(p.position) == "table")
end

while true do
    local sender, packet = rednet.receive(protocol, 1)
    if sender and (not filter or sender == filter) and valid(packet, sender) then
        -- Bounded device list for long-running displays.
        if not devices[sender] then
            local count, oldestId, oldestTime = 0, nil, math.huge
            for id, entry in pairs(devices) do
                count = count + 1
                if entry.received < oldestTime then oldestId, oldestTime = id, entry.received end
            end
            if count >= 32 then devices[oldestId] = nil end
        end
        devices[sender] = { packet = packet, received = os.clock() }
        lastMessage = "Posledna sprava od #" .. sender
    end
    draw()
end
