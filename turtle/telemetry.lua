local network = require("network")
local inv = require("inventory")
local telemetry = {}
local options = { enabled = true, protocol = "craftoria.turtle.v1", interval = 2 }
local provider
local lastAttempt = -math.huge
local sequence = 0
local activity = "idle"
local progress
local context
function telemetry.setContext(value) context = value end
function telemetry.getActivity() return activity end

-- Retain job counters during navigation, unloading and refuelling messages.
function telemetry.setProgress(value)
    progress = value
end
function telemetry.getProgress()
    if not progress then return nil end
    return { visited = progress.visited, completed = progress.completed, total = progress.total,
        remaining = progress.remaining, dug = progress.dug, phase = progress.phase,
        placed = progress.placed, skipped = progress.skipped, taskType = progress.taskType, block = progress.block }
end

function telemetry.configure(settings, positionProvider)
    options = settings or options
    provider = positionProvider or provider
end

function telemetry.setActivity(value)
    activity = value
    return telemetry.emit("info", value, nil, false)
end

-- Network failures must not stop movement or resource checks.
function telemetry.emit(level, message, details, force)
    if not options.enabled then return false, "disabled" end
    if not force and os.clock() - lastAttempt < options.interval then return true end
    -- A missing modem must not trigger a new discovery attempt every step.
    lastAttempt = os.clock()
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
            context = context,
        }
        if progress then
            packet.progress = telemetry.getProgress()
        end
        if options.receiverId then rednet.send(options.receiverId, packet, options.protocol)
        else rednet.broadcast(packet, options.protocol) end
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
