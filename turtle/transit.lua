-- Defined floor exits; traffic uses separate columns and short floor gates.
local config = require("config")
local transit = {}
local settings, workBox, workFloor,preferredLane

function transit.validate(tunnel)
    if tunnel == nil then return true end
    if type(tunnel) ~= "table" or type(tunnel.floors) ~= "table"
        or not config.isPoint({ x = tunnel.x, y = 0, z = tunnel.z }) then return false, "invalid_tunnel" end
    local heights = {}
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
function transit.move(target, options, rawMove, acquire, release, position, onEntered)
    local legs = options.maxMoves == 1 and {} or transit.plan(position(), target)
    if #legs == 0 then return rawMove(target.x, target.y, target.z, options) end
    return require("tunnel_traffic").move(legs,target,options,rawMove,acquire,release,position,onEntered,preferredLane)
end
return transit
