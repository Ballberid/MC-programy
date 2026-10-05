-- Three exclusive columns inside the existing 3x3 shaft. Floor junctions
-- serialize only horizontal entry/exit, never the whole vertical journey.
local traffic = {}
function traffic.lane(up,preferred)
    if up then
        local index=preferred or os.getComputerID()%2+1
        return "tunnel:up:"..index, -1, index==1 and -1 or 1
    end
    return "tunnel:down", 1, 0
end
local function gate(p) return "door:"..p.x..","..p.y..","..p.z end
function traffic.move(legs,target,options,rawMove,acquire,release,position,onEntered,preferred)
    local first,last=legs[2].point,legs[3].point
    local up=last.y>first.y
    local lane,dx,dz=traffic.lane(up,preferred)
    local sourceGate,destinationGate=gate(first),gate(last)
    local function take(resource)
        local ok,err=acquire(resource)
        return ok,err
    end
    local function move(p,straight)
        local o={}; for k,v in pairs(options) do o[k]=v end
        o.direction=nil
        if straight then
            -- Returning may use a different column than the outbound journey.
            -- Explore only these defined straight legs, with normal detection.
            o.maxDetour,o.knownOnly,o.waitForTurtles=0,false,true
        end
        local current=position()
        if current and math.abs(current.x-p.x)+math.abs(current.y-p.y)+math.abs(current.z-p.z)<=1 then
            o.maxMoves,o.positionVerified=1,true
        end
        local ok,err=rawMove(p.x,p.y,p.z,o)
        return ok,ok and nil or "transit:"..tostring(err)
    end
    local function point(x,y,z) return {x=x,y=y,z=z} end
    local locked,err=take(lane); if not locked then return false,err end
    locked,err=take(sourceGate); if not locked then return false,err end
    -- Gate ownership includes the outside doorway and all horizontal bends.
    for _,leg in ipairs({legs[1].point,first,point(first.x+dx,first.y,first.z),point(first.x+dx,first.y,first.z+dz)}) do
        local ok,reason=move(leg,leg~=legs[1].point)
        if not ok then return false,reason end
    end
    release(sourceGate)
    if onEntered then onEntered() end
    -- Wait one level before the destination. Never park in a horizontal
    -- junction while another worker owns that floor's gate.
    local guard=point(first.x+dx,last.y-(up and 1 or -1),first.z+dz)
    local ok,reason=move(guard,true); if not ok then return false,reason end
    locked,err=take(destinationGate); if not locked then return false,err end
    for _,p in ipairs({point(first.x+dx,last.y,first.z+dz),point(first.x+dx,last.y,first.z),last,legs[4].point}) do
        ok,reason=move(p,true); if not ok then return false,reason end
    end
    release(destinationGate); release(lane)
    return rawMove(target.x,target.y,target.z,options)
end
return traffic
