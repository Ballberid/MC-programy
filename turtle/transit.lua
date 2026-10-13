-- Defined floor exits; traffic uses separate columns and short floor gates.
local config = require("config")
local transit = {}
local settings, workBox, workFloor,preferredLane

function transit.validate(tunnel)
    if tunnel == nil then return true end
    if type(tunnel) ~= "table" or type(tunnel.floors) ~= "table"
        or not config.isPoint({ x = tunnel.x, y = 0, z = tunnel.z }) then return false, "invalid_tunnel" end
    local heights = {}
    if tunnel.wide~=nil and type(tunnel.wide)~="boolean" then return false,"invalid_tunnel_mode" end
    if not next(tunnel.floors) then return false, "tunnel_has_no_floors" end
    for name, floor in pairs(tunnel.floors) do
        if type(name) ~= "string" or name == "" or type(floor) ~= "table" or not config.isPoint(floor.exit) then return false, "invalid_floor" end
        local p = floor.exit
        if heights[p.y] then return false, "duplicate_floor_height" end
        heights[p.y] = true
        -- A straight horizontal doorway avoids guessing the bend in a building.
        if not ((p.x == tunnel.x and math.abs(p.z - tunnel.z) >= 2)
            or (p.z == tunnel.z and math.abs(p.x - tunnel.x) >= 2)) then return false, "exit_must_align_with_shaft" end
    end
    if tunnel.wide then
        local levels={}; for y in pairs(heights) do levels[#levels+1]=y end; table.sort(levels)
        for i=2,#levels do if levels[i]-levels[i-1]<5 then return false,"wide_floors_need_five_blocks" end end
    end
    return true
end
function transit.configure(tunnel, box, floorName, lane)
    local ok, err = transit.validate(tunnel)
    if not ok then return false, err end
    if tunnel and (not floorName or not tunnel.floors[floorName]) then return false, "work_floor_missing" end
    if lane~=nil and lane~=1 and lane~=2 then return false,"invalid_tunnel_lane" end
    settings, workBox, workFloor,preferredLane = tunnel, box, floorName,lane
    return true
end
local function floorFor(p)
    if workBox then
        local near = true
        for _, axis in ipairs({ "x", "y", "z" }) do
            if p[axis] < workBox.min[axis] - 1 or p[axis] > workBox.max[axis] + 1 then near = false end
        end
        if near then return workFloor end
    end
    local name, distance
    for candidate, floor in pairs(settings.floors) do
        local d = math.abs(p.y - floor.exit.y)
        if not distance or d < distance then name, distance = candidate, d end
    end
    return name
end
function transit.plan(from, target)
    if not settings then return {} end
    local a, b = floorFor(from), floorFor(target)
    if not a or not b or a == b then return {} end
    local first, last = settings.floors[a].exit, settings.floors[b].exit
    return {
        { point = first },
        { point = { x = settings.x, y = first.y, z = settings.z }, straight = true },
        { point = { x = settings.x, y = last.y, z = settings.z }, straight = true },
        { point = last, straight = true },
    }
end
function transit.estimate(from, target)
    local function distance(a, b) return math.abs(a.x-b.x) + math.abs(a.y-b.y) + math.abs(a.z-b.z) end
    local cost, previous = 0, from
    for _, leg in ipairs(transit.plan(from, target)) do
        cost, previous = cost + distance(previous, leg.point), leg.point
    end
    return cost + distance(previous, target) + (#transit.plan(from,target)>0 and 8 or 0)
end
-- Release failed/retried traffic only after GPS confirms the turtle is clear.
function transit.canRelease(resource,p)
    if not settings or not p or type(resource)~="string" then return false end
    local function contains(box)
        for _,axis in ipairs({"x","y","z"}) do
            if p[axis]<box.min[axis] or p[axis]>box.max[axis] then return false end
        end
        return true
    end
    local function corridor(exit)
        if settings.wide then return require("tunnel_layout").corridor(settings,exit) end
        return {min={x=math.min(settings.x-1,exit.x),y=exit.y,z=math.min(settings.z-1,exit.z)},
            max={x=math.max(settings.x+1,exit.x),y=exit.y,z=math.max(settings.z+1,exit.z)}}
    end
    if resource:match("^door:") then
        for _,floor in pairs(settings.floors) do
            if resource=="door:"..settings.x..","..floor.exit.y..","..settings.z then
                return not contains(corridor(floor.exit))
            end
        end
        return false
    end
    if resource=="tunnel:pool" or resource:match("^tunnel:lane:[1-9]$")
        or resource=="tunnel:up:1" or resource=="tunnel:up:2" or resource=="tunnel:down" then
        if math.abs(p.x-settings.x)<=1 and math.abs(p.z-settings.z)<=1 then return false end
        for _,floor in pairs(settings.floors) do if contains(corridor(floor.exit)) then return false end end
        return true
    end
    return false
end
function transit.move(target, options, rawMove, acquire, release, position, onEntered, destinationMove)
    local legs = options.maxMoves == 1 and {} or transit.plan(position(), target)
    if #legs == 0 then return (destinationMove or rawMove)(target.x, target.y, target.z, options) end
    if settings.wide then return require("wide_tunnel").move(legs,target,options,rawMove,acquire,release,position,onEntered,destinationMove) end
    return require("tunnel_traffic").move(legs,target,options,rawMove,acquire,release,position,onEntered,preferredLane,destinationMove)
end
return transit
