-- Reserve shared travel before departing, and retain it while parked at a chest.
local transit = require("transit")
local motion = {}
function motion.new(client, stations, position)
    local parked = false
    local function atStation(p)
        for _, s in pairs(stations) do if p.x == s.x and p.y == s.y and p.z == s.z then return true end end
        return false
    end
    return function(target, options, rawMove)
        if options.maxMoves == 1 then return rawMove(target.x, target.y, target.z, options) end
        local locked, err = client.acquire("service")
        if not locked then return false, err end
        local ok, reason, details = transit.move(target, options, rawMove, client.acquire, client.release, position)
        if ok then
            if atStation(target) and not parked then parked = true
            else client.release("service") end
            if not atStation(target) and parked then parked = false; client.release("service") end
        end
        return ok, reason, details
    end
end
return motion
