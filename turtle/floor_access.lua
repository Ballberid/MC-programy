-- Bounded access to either side of a floor block, without digging.
local nav = require("navigation")
local supplies = require("supplies")
local config = require("config")
local telemetry = require("telemetry")
local access = {}
function access.stand(block, side)
    return { x = block.x, y = block.y + (side == "up" and -1 or 1), z = block.z }
end
function access.reach(block, preferred)
    local start = nav.getPosition()
    local c = config.load()
    local sides = { "down", "up" }
    if preferred == "up" or (not preferred and start.y < block.y) then sides = { "up", "down" } end
    local lastError
    for _, side in ipairs(sides) do
        local target = access.stand(block, side)
        local distance = nav.estimateDistance(target)
        local ready, reason = supplies.ensure({ moves = distance + 12 })
        if not ready then return nil, reason end
        local options = assert(supplies.navigationOptions())
        options.maxDetour = math.min(2, c.navigation.maxDetour)
        options.maxMoves = math.min(c.navigation.maxMoves, distance + 12)
        options.maxReplans = 8
        local actualDistance = nav.distance(nav.getPosition(), target)
        -- Adjacent work moves bypass fleet service travel; a failed direct
        -- attempt may still be retried with the bounded detour below.
        if actualDistance == 1 then options.maxMoves, options.maxDetour = 1, 0 end
        if not preferred or preferred ~= side or actualDistance > 1 then
            telemetry.log("Podlaha: pristup " .. (side == "down" and "zhora" or "zdola")
                .. " na " .. target.x .. "," .. target.y .. "," .. target.z)
        end
        local ok, err = nav.moveToCoord(target.x, target.y, target.z, options)
        if not ok and actualDistance == 1 and (err == "target_unreachable" or err == "no_route") then
            options.maxMoves, options.maxDetour = math.min(c.navigation.maxMoves, distance + 12), math.min(2, c.navigation.maxDetour)
            ok, err = nav.moveToCoord(target.x, target.y, target.z, options)
        end
        if ok then return side, target end
        lastError = err
        if err ~= "target_unreachable" and err ~= "no_route" and err ~= "move_limit"
            and err ~= "replan_limit" and err ~= "search_limit" then return nil, err end
        -- Never chain explorations away from the last verified work point.
        local back = assert(supplies.navigationOptions()); back.knownOnly, back.direction = true, start.direction
        back.maxMoves = distance + 12
        local returned, returnErr = nav.moveToCoord(start.x, start.y, start.z, back)
        if not returned then return nil, "approach_return_failed:" .. tostring(returnErr) end
    end
    return nil, "floor_unreachable_both_sides:" .. tostring(lastError)
end
function access.inspect(side)
    return (side == "up" and turtle.inspectUp or turtle.inspectDown)()
end
function access.place(side)
    return (side == "up" and turtle.placeUp or turtle.placeDown)()
end
return access
