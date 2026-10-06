-- Serialize only crossing the shared room opening, never the wall work itself.
local nav=require("navigation")
local cuboid=require("cuboid")
local plan=require("wall_plan")
local traffic={}
function traffic.new(client,box,base)
    local resource="wallgate:"..client.state.task.jobId
    local gate=box.opening
    local outward=gate.x==box.min.x and -1 or 1
    local outer={x=gate.x+outward,y=gate.y,z=gate.z}
    local inner={x=gate.x-outward,y=gate.y,z=gate.z}
    local function interior(p) return cuboid.contains(box,p) and not plan.isWall(box,p) end
    return function(target,options,rawMove)
        local current=nav.getPosition()
        if interior(current)==interior(target) then return base(target,options,rawMove) end
        if not client.held[resource] and (nav.distance(current,inner)==0 or nav.distance(current,outer)==0) then
            -- A builder can finish a neighbouring tile at a doorway endpoint.
            -- Clear that endpoint before waiting for a worker coming the other way.
            local moved,lastError=false
            for _,d in ipairs({{1,0,0},{-1,0,0},{0,0,1},{0,0,-1},{0,1,0},{0,-1,0}}) do
                local q={x=current.x+d[1],y=current.y+d[2],z=current.z+d[3]}
                if interior(q)==interior(current) and not plan.isWall(box,q) then
                    local aside={}; for k,v in pairs(options) do aside[k]=v end
                    aside.maxMoves,aside.maxDetour,aside.positionVerified,aside.tryOnce=1,0,true,true
                    aside.waitForTarget,aside.waitForTurtles,aside.direction=false,false,nil
                    local ok,err=base(q,aside,rawMove)
                    if ok then moved=true; break end
                    if err=="job_cancelled" or err=="fuel_reserve" or err=="position_mismatch" then return false,err end
                    lastError=err
                end
            end
            if not moved then return false,"wall_gate_parking_blocked:"..tostring(lastError) end
        end
        -- Acquire before approaching so opposing workers do not occupy both
        -- ends of a one-block doorway and wait forever for each other.
        if not client.held[resource] then
            local ok,err=client.acquire(resource); if not ok then return false,err end
        end
        local first,second=outer,inner
        if interior(current) then first,second=inner,outer end
        local o={}; for k,v in pairs(options) do o[k]=v end
        o.direction=nil; o.waitForTarget=true
        local ok,err=base(first,o,rawMove); if not ok then return false,err end
        local crossing={}; for k,v in pairs(o) do crossing[k]=v end
        crossing.maxDetour=0; crossing.maxMoves=2
        ok,err=base(second,crossing,rawMove)
        if not ok then return false,err end -- Retain claim until recovery exits safely.
        client.release(resource)
        return base(target,options,rawMove)
    end
end
return traffic
