-- Reserve only the exact chest parking point; ordinary travel is concurrent.
local transit = require("transit")
local nav = require("navigation")
local motion = {}
function motion.new(client, stations, position, dock)
    local parked,parking
    local function same(a,b) return a and b and a.x==b.x and a.y==b.y and a.z==b.z end
    local function stationAt(p)
        for _,s in pairs(stations) do if same(p,s) then return "station:"..s.x..","..s.y..","..s.z end end
    end
    local function releaseParking()
        if parked then client.release(parked); parked,parking=nil,nil end
    end
    local function leaveParking(target,options,rawMove)
        if not parked then return true end
        local p=position()
        if not same(p,parking) then releaseParking(); return true end
        local candidates={}
        for _,d in ipairs({{1,0,0},{-1,0,0},{0,0,1},{0,0,-1},{0,1,0},{0,-1,0}}) do
            local q={x=p.x+d[1],y=p.y+d[2],z=p.z+d[3]}
            if not stationAt(q) and not same(q,dock) then candidates[#candidates+1]=q end
        end
        table.sort(candidates,function(a,b) return nav.distance(a,target)<nav.distance(b,target) end)
        while true do
        local temporary=false
        for _,q in ipairs(candidates) do
            local o={}; for k,v in pairs(options) do o[k]=v end
            o.maxMoves,o.maxDetour,o.knownOnly,o.tryOnce,o.waitForTarget,o.waitForTurtles=1,0,false,true,false,false
            o.positionVerified=true
            local ok,err=rawMove(q.x,q.y,q.z,o)
            if ok then releaseParking(); return true end
            if err=="job_cancelled" or err=="fuel_reserve" or err=="position_mismatch"
                or err=="position_uninitialized" or tostring(err):find("gps",1,true) then return false,err end
            temporary=temporary or tostring(err):find("temporary",1,true)~=nil
        end
        if not temporary then return false,"station_exit_blocked" end
        local allowed,denied=nav.checkpoint(); if not allowed then return false,denied end
        sleep(0.5)
        end
    end
    local function move(target,options,rawMove)
        local resource=stationAt(target)
        if parked and not same(parking,target) then
            local ok,err=leaveParking(target,options,rawMove); if not ok then return false,err end
        end
        if resource and parked~=resource then
            -- A worker may already reserve its first chest while still docked.
            -- Adopt that claim rather than nesting it and keeping it after departure.
            if not (client.held and client.held[resource]) then
                local ok,err=client.acquire(resource); if not ok then return false,err end
            end
            parked,parking=resource,{x=target.x,y=target.y,z=target.z}
        end
        local ok,err,details=transit.move(target,options,rawMove,client.acquire,client.release,position)
        if not ok and not same(position(),parking) then releaseParking() end
        return ok,err,details
    end
    return move,leaveParking
end
return motion
