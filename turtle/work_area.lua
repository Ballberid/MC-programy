-- Saved footprints contain X/Z only. Expand wall inputs once, before dispatch.
local area={}
local function point(p)
    if type(p)~="table" then return false end
    for _,axis in ipairs({"x","z"}) do
        local n=p[axis]
        if type(n)~="number" or n%1~=0 or math.abs(n)>30000000 then return false end
    end
    return true
end
function area.valid(zone)
    return type(zone)=="table" and point(zone.min) and point(zone.max)
        and zone.min.x<=zone.max.x and zone.min.z<=zone.max.z
end
function area.footprint(a,b)
    if not point(a) or not point(b) then return nil,"invalid_work_zone" end
    return {min={x=math.min(a.x,b.x),z=math.min(a.z,b.z)},
        max={x=math.max(a.x,b.x),z=math.max(a.z,b.z)}}
end
function area.bounds(zone,firstY,lastY,kind,includeCorners)
    if not area.valid(zone) then return nil,"invalid_work_zone" end
    for _,y in ipairs({firstY,lastY}) do
        if type(y)~="number" or y%1~=0 or math.abs(y)>30000000 then return nil,"invalid_work_height" end
    end
    if firstY==nil or lastY==nil then return nil,"invalid_work_height" end
    local margin=kind=="walls" and not includeCorners and 1 or 0
    local a={x=zone.min.x-margin,y=firstY,z=zone.min.z-margin}
    local b={x=zone.max.x+margin,y=lastY,z=zone.max.z+margin}
    if kind=="floor" or kind=="ceiling" then b.y=a.y end
    if not point(a) or not point(b) then return nil,"invalid_work_zone" end
    return a,b
end
return area
