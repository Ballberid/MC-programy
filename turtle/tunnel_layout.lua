-- Nine shaft columns and their matching cells in a vertical 3x3 doorway.
local layout={}
function layout.lane(index)
    return (index-1)%3-1,math.floor((index-1)/3)-1
end
function layout.portal(center,shaft,index)
    local dx,dz=layout.lane(index)
    if center.x~=shaft.x then
        return {x=center.x,y=center.y+dx,z=center.z+dz},dx,dz
    end
    return {x=center.x+dx,y=center.y+dz,z=center.z},dx,dz
end
function layout.corridor(tunnel,p)
    local alongX=p.x~=tunnel.x
    local outX=alongX and (p.x>tunnel.x and 1 or -1) or 0
    local outZ=not alongX and (p.z>tunnel.z and 1 or -1) or 0
    return {min={x=math.min(tunnel.x-1,p.x+outX-(alongX and 0 or 1)),y=p.y-1,
        z=math.min(tunnel.z-1,p.z+outZ-(alongX and 1 or 0))},
        max={x=math.max(tunnel.x+1,p.x+outX+(alongX and 0 or 1)),y=p.y+1,
        z=math.max(tunnel.z+1,p.z+outZ+(alongX and 1 or 0))}}
end
return layout
