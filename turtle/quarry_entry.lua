local cuboid = require("cuboid")
local nav = require("navigation")
local telemetry = require("telemetry")
local entry = {}
local retryable = {
    target_unreachable = true, no_route = true, search_limit = true,
    move_limit = true, replan_limit = true,
}

-- Try a finite set of top/side approaches. A blocked outside cell is never
-- dug out: only the cell INSIDE the box is passed to the mining callback.
function entry.enter(box, progress, travel, digStep, connectInside, firstCorner)
    local p = nav.getPosition()
    firstCorner = firstCorner or { x = box.min.x, y = box.max.y, z = box.min.z }
    local function connect()
        telemetry.log("Prekopavam sa v oblasti k prvemu rohu " .. firstCorner.x .. "," .. firstCorner.y .. "," .. firstCorner.z, "info")
        local ok, err = connectInside(firstCorner, box, progress)
        if not ok then return nil, err end
        return firstCorner
    end
    if cuboid.contains(box, p) then
        return connect()
    end
    progress.entryAttempts = {}
    local below = { x = p.x, y = p.y - 1, z = p.z }
    if cuboid.contains(box, below) then
        telemetry.log("Vstupujem pod turtle: " .. below.x .. "," .. below.y .. "," .. below.z, "info")
        local ok, err = digStep(below, box, progress)
        if not ok then return nil, err end
        progress.localEntry = below
        return connect()
    end
    local approaches = cuboid.approaches(box, p, firstCorner)
    -- Account for the actual route through a service shaft when selecting
    -- an exterior neighbour of the requested first corner.
    table.sort(approaches, function(a, b)
        local da, db = nav.estimateDistance(a.stand), nav.estimateDistance(b.stand)
        if da == db then return a.order < b.order end
        return da < db
    end)
    for index, approach in ipairs(approaches) do
        local stand, target = approach.stand, approach.cell
        telemetry.log("Pristup " .. index .. "/" .. #approaches .. ": turtle na "
            .. stand.x .. "," .. stand.y .. "," .. stand.z .. " -> blok "
            .. target.x .. "," .. target.y .. "," .. target.z, "info")
        local arrived, err = travel(stand)
        progress.entryAttempts[#progress.entryAttempts + 1] = { stand = stand, error = err }
        if arrived then
            local entered, digErr = digStep(target, box, progress)
            if not entered then return nil, digErr end
            return target
        end
        telemetry.log("Pristup nepristupny: " .. tostring(err), "warning", { stand = stand })
        -- A fuel/GPS/service failure is not evidence that another entrance
        -- will help. Stop instead of repeating resource failures everywhere.
        if not retryable[err] then return nil, "entry_unreachable:" .. tostring(err) end
    end
    return nil, "entry_unreachable:all_approaches_blocked"
end

return entry
