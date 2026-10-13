-- The PC leases a whole column. Floor crossings serialize only the short
-- approach/exit; the nine vertical journeys can proceed concurrently.
local layout=require("tunnel_layout")
local wide={}
function wide.move(legs,target,options,rawMove,acquire,release,position,onEntered,destinationMove)
    local first,last=legs[2].point,legs[3].point
    local shaft={x=first.x,z=first.z}
    local ok,err,resource=acquire("tunnel:pool")
    if not ok then return false,err end
    local index=tonumber(tostring(resource):match("^tunnel:lane:([1-9])$"))
    if not index then return false,"invalid_tunnel_lane_reply" end
    local entry,dx,dz=layout.portal(legs[1].point,shaft,index)
    local exit=layout.portal(legs[4].point,shaft,index)
    local up=exit.y>entry.y
    local function gate(p) return "door:"..p.x..","..p.y..","..p.z end
    local function move(p,straight)
        local o={}; for k,v in pairs(options) do o[k]=v end
        o.direction=nil
        if straight then o.maxDetour,o.knownOnly,o.waitForTurtles=0,false,true end
        local worked,reason=rawMove(p.x,p.y,p.z,o)
        return worked,worked and nil or "transit:"..tostring(reason)
    end
    local source,dest=gate(first),gate(last)
    ok,err=acquire(source); if not ok then return false,err end
    ok,err=move(entry,false); if not ok then return false,err end
    ok,err=move({x=first.x+dx,y=entry.y,z=first.z+dz},true); if not ok then return false,err end
    release(source); if onEntered then onEntered() end
    -- Keep waiting columns outside every doorway's three vertical rows.
    ok,err=move({x=first.x+dx,y=last.y+(up and -2 or 2),z=first.z+dz},true)
    if not ok then return false,err end
    ok,err=acquire(dest); if not ok then return false,err end
    ok,err=move({x=first.x+dx,y=exit.y,z=first.z+dz},true); if not ok then return false,err end
    ok,err=move(exit,true); if not ok then return false,err end
    local outside={x=exit.x,y=exit.y,z=exit.z}
    if legs[4].point.x~=first.x then outside.x=outside.x+(exit.x>first.x and 1 or -1)
    else outside.z=outside.z+(exit.z>first.z and 1 or -1) end
    ok,err=move(outside,true); if not ok then return false,err end
    release(dest); release(resource)
    return (destinationMove or rawMove)(target.x,target.y,target.z,options)
end
return wide
