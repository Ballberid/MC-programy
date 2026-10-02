local fuel = require("fuel")
local config = require("config")
local position = {}
local current
local vectors = { [0] = { x = 0, z = -1 }, { x = 1, z = 0 }, { x = 0, z = 1 }, { x = -1, z = 0 } }

function position.get()
    if not current then return nil end
    return { x = current.x, y = current.y, z = current.z, direction = current.direction }
end

function position.offset(p, direction, side)
    local q = { x = p.x, y = p.y, z = p.z }
    if side == "up" then q.y = q.y + 1
    elseif side == "down" then q.y = q.y - 1
    else q.x = q.x + vectors[direction].x; q.z = q.z + vectors[direction].z end
    return q
end

function position.locate()
    local x, y, z = gps.locate(5)
    local p = { x = x, y = y, z = z }
    if not config.isPoint(p) then return nil, "gps_unavailable" end
    return p
end

function position.sync()
    local p, err = position.locate()
    if not p then return false, err end
    if not current then return false, "position_uninitialized" end
    if current.x ~= p.x or current.y ~= p.y or current.z ~= p.z then
        -- A mismatch could be a teleport. Invalidate heading and map in caller.
        current = nil
        return false, "position_mismatch"
    end
    return true
end

function position.turnTo(target)
    if not current then return false, "position_uninitialized" end
    if not config.isDirection(target) then return false, "invalid_direction" end
    local turn = (target - current.direction) % 4
    if turn == 3 then
        if not turtle.turnLeft() then return false, "turn_failed" end
        current.direction = (current.direction + 3) % 4
    else
        for _ = 1, turn do
            if not turtle.turnRight() then return false, "turn_failed" end
            current.direction = (current.direction + 1) % 4
        end
    end
    return true
end

function position.move(side)
    if not current then return false, "position_uninitialized" end
    local fn = ({ front = turtle.forward, back = turtle.back, up = turtle.up, down = turtle.down })[side]
    if not fn then return false, "invalid_move" end
    local ok, err = fn()
    if not ok then return false, err end
    local direction = side == "back" and (current.direction + 2) % 4 or current.direction
    local p = position.offset(current, direction, side)
    current.x, current.y, current.z = p.x, p.y, p.z
    return true
end

-- Detect heading with a probe, then restore both position and original heading.
-- A manually supplied heading avoids moving at initialization.
function position.init(heading, options, fuelSlots)
    current = nil
    options = options or config.defaults().navigation
    local start, err = position.locate()
    if not start then return false, err end
    if heading ~= nil then
        if not config.isDirection(heading) then return false, "invalid_direction" end
        start.direction = heading
        current = start
        return true
    end
    local turns, height, found, failure = 0, 0, nil, "direction_blocked"
    for h = 0, options.maxProbeHeight do
        for _ = 1, 4 do
            if not turtle.detect() then
                if not fuel.ensure(height + 2 + options.reserve, fuelSlots) then
                    failure = "insufficient_fuel"; break
                end
                local before = position.locate()
                if not before then failure = "gps_unavailable"; break end
                if turtle.forward() then
                    local after = position.locate()
                    -- Always attempt rollback even when the second GPS query fails.
                    if not turtle.back() then return false, "probe_restore_failed" end
                    if not after then failure = "gps_unavailable"; break end
                    local dx, dz = after.x - before.x, after.z - before.z
                    if dx == 1 and dz == 0 then found = 1
                    elseif dx == -1 and dz == 0 then found = 3
                    elseif dz == 1 and dx == 0 then found = 2
                    elseif dz == -1 and dx == 0 then found = 0 end
                    if found then found = (found - turns) % 4; break end
                    failure = "probe_position_invalid"; break
                end
            end
            if not turtle.turnRight() then failure = "turn_failed"; break end
            turns = (turns + 1) % 4
        end
        if found or failure ~= "direction_blocked" then break end
        if h == options.maxProbeHeight or turtle.detectUp() then break end
        if not fuel.ensure(height + 2 + options.reserve, fuelSlots) then failure = "insufficient_fuel"; break end
        if not turtle.up() then break end
        height = height + 1
    end
    for _ = 1, turns do
        if not turtle.turnLeft() then return false, "probe_restore_failed" end
    end
    for _ = 1, height do
        if not turtle.down() then return false, "probe_restore_failed" end
    end
    if not found then return false, failure end
    local restored = position.locate()
    if not restored then return false, "gps_unavailable" end
    if restored.x ~= start.x or restored.y ~= start.y or restored.z ~= start.z then
        return false, "probe_restore_failed"
    end
    start.direction = found
    current = start
    return true
end

return position
