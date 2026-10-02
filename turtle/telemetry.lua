local network = require("network")
local inv = require("inventory")
local telemetry = {}
local options = { enabled = true, protocol = "craftoria.turtle.v1", interval = 2 }
local provider
local lastSent = -math.huge
local sequence = 0
local activity = "idle"

function telemetry.configure(settings, positionProvider)
    options = settings or options
    provider = positionProvider or provider
end

function telemetry.setActivity(value)
    activity = value
    return telemetry.emit("info", value, nil, true)
end

-- Network failures must not stop movement or resource checks.
function telemetry.emit(level, message, details, force)
    if not options.enabled then return false, "disabled" end
    if not force and os.clock() - lastSent < options.interval then return true end
    local ok, result, err = pcall(function()
        local ready, reason = network.open()
        if not ready then return false, reason end
        sequence = sequence + 1
        local packet = {
            version = 1, id = os.getComputerID(), label = os.getComputerLabel(),
            sequence = sequence, time = os.epoch("utc"), activity = activity,
            level = level, message = tostring(message), details = details,
            position = provider and provider() or nil,
            fuel = turtle.getFuelLevel(), inventory = inv.snapshot(),
        }
        if options.receiverId then rednet.send(options.receiverId, packet, options.protocol)
        else rednet.broadcast(packet, options.protocol) end
        lastSent = os.clock()
        return true
    end)
    if not ok then return false, tostring(result) end
    return result, err
end

function telemetry.log(message, level, details)
    print(message)
    return telemetry.emit(level or "info", message, details, true)
end

-- Optional wrapper for future programs: forwards their print output and
-- restores the original print even when the wrapped program fails.
function telemetry.capture(fn, ...)
    local original = print
    print = function(...)
        original(...)
        local words = {}
        for i = 1, select("#", ...) do words[i] = tostring(select(i, ...)) end
        telemetry.emit("info", table.concat(words, " "), nil, true)
    end
    local result = table.pack(pcall(fn, ...))
    print = original
    if not result[1] then error(result[2], 0) end
    return table.unpack(result, 2, result.n)
end

return telemetry
