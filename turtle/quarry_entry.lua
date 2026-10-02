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
function entry.enter(box, progress, travel, digStep, connectInside)
    local p = nav.getPosition()
    if cuboid.contains(box, p) then
        local target = cuboid.entry(box, p)
        local ok, err = connectInside(target, box, progress)
        if not ok then return nil, err end
        return target
    end
    local approaches = cuboid.approaches(box, p)
    progress.entryAttempts = {}
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
