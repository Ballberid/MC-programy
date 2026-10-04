-- Reserve service travel/parking; hand it off once outbound shaft entry is clear.
local transit = require("transit")
local motion = {}
function motion.new(client, stations, position, dock)
    local parked = false
    local function atStation(p)
        for _, s in pairs(stations) do if p.x == s.x and p.y == s.y and p.z == s.z then return true end end
        return false
    end
    local function serviceFloor(p)
        if dock and #transit.plan(p, dock) == 0 then return true end
        for _, s in pairs(stations) do if #transit.plan(p, s) == 0 then return true end end
        return false
    end
    return function(target, options, rawMove)
        if options.maxMoves == 1 then return rawMove(target.x, target.y, target.z, options) end
        local locked, err = client.acquire("service")
        if not locked then return false, err end
        local handedOff = false
        local function entered()
            -- Only release our own movement/parking claims. A station visit's
            -- outer reservation remains held across its complete round trip.
            -- Returning to any service floor keeps service until arrival, so
            -- nobody holding the tunnel ever waits to reacquire service.
            if not serviceFloor(target) then
                client.release("service")
                if parked then parked = false; client.release("service") end
                handedOff = true
            end
        end
        local ok, reason, details = transit.move(target, options, rawMove, client.acquire, client.release, position, entered)
        if ok and not handedOff then
            if atStation(target) and not parked then parked = true
            else client.release("service") end
            if not atStation(target) and parked then parked = false; client.release("service") end
        end
        return ok, reason, details
    end
end
return motion
