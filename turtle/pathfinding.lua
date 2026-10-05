local pathfinding = {}
local cells = {}
local blocked = {}
local temporary = {}
local avoid
local function excluded(p)
    if not avoid or p.x<avoid.min.x or p.x>avoid.max.x or p.y<avoid.min.y or p.y>avoid.max.y
        or p.z<avoid.min.z or p.z>avoid.max.z then return false end
    if not avoid.walls then return true end
    local g=avoid.opening
    if g and p.x==g.x and p.y==g.y and p.z==g.z then return false end
    return p.x==avoid.min.x or p.x==avoid.max.x or p.z==avoid.min.z or p.z==avoid.max.z
end
local function knownFree(p)
    if excluded(p) then return false end
    return cells[pathfinding.key(p)]==true
end
local verified=require("verified_routes").new(knownFree)
-- Reserve a future construction volume without allocating every cell.
-- It survives map resets and obstacle refreshes until the caller restores it.
function pathfinding.setAvoid(box)
    local previous = avoid
    avoid = box
    verified.clear()
    return previous
end
local directions = {
    { x = 1, y = 0, z = 0 }, { x = -1, y = 0, z = 0 },
    { x = 0, y = 0, z = 1 }, { x = 0, y = 0, z = -1 },
    { x = 0, y = 1, z = 0 }, { x = 0, y = -1, z = 0 },
}

function pathfinding.key(p)
    return p.x .. "," .. p.y .. "," .. p.z
end

function pathfinding.distance(a, b)
    return math.abs(a.x - b.x) + math.abs(a.y - b.y) + math.abs(a.z - b.z)
end

function pathfinding.mark(p, free)
    local key=pathfinding.key(p); local old=cells[key]
    temporary[key] = nil
    cells[key] = free
    blocked[key] = free == false or nil
    if old==true and free~=true then verified.clear()
    elseif free==true and old~=true then verified.add(p) end
end
function pathfinding.markTemporary(p)
    local key=pathfinding.key(p)
    local prior=temporary[key]
    if cells[key]==true then verified.clear() end
    temporary[key]={previous=prior and prior.previous or cells[key], untilTime=os.clock()+5}
    cells[key]=false
end
function pathfinding.refreshTemporary()
    for key,entry in pairs(temporary) do
        if os.clock()>=entry.untilTime then
            cells[key]=entry.previous; temporary[key]=nil
            if entry.previous==true then verified.clear() end
        end
    end
end
function pathfinding.hasTemporary()
    pathfinding.refreshTemporary(); return next(temporary)~=nil
end

function pathfinding.clear()
    cells, temporary, blocked = {}, {}, {}
    verified.clear()
end

function pathfinding.forgetBlocked()
    for key,entry in pairs(temporary) do
        cells[key]=entry.previous
        if entry.previous==true then verified.clear() end
    end
    temporary={}
    -- Do not scan every visited quarry cell on every one-block movement.
    for key in pairs(blocked) do if cells[key] == false then cells[key] = nil end end
    blocked={}
end

function pathfinding.knownDistance(start,goal,maxNodes)
    pathfinding.refreshTemporary()
    return verified.distance(start,goal,function(a,b)
        return pathfinding.find(a,b,{knownOnly=true,maxNodes=maxNodes})
    end)
end

local function before(a, b)
    if a.score ~= b.score then return a.score < b.score end
    -- Equal shortest-path estimates are common across large open quarries.
    -- Prefer progress toward the goal instead of expanding the whole volume.
    return a.cost > b.cost
end

local function push(heap, entry)
    local i = #heap + 1
    heap[i] = entry
    while i > 1 do
        local parent = math.floor(i / 2)
        if not before(entry, heap[parent]) then break end
        heap[i] = heap[parent]; i = parent; heap[i] = entry
    end
end

local function pop(heap)
    local result = heap[1]
    local last = table.remove(heap)
    if #heap > 0 then
        heap[1] = last
        local i = 1
        while i * 2 <= #heap do
            local child = i * 2
            if child < #heap and before(heap[child + 1], heap[child]) then child = child + 1 end
            if not before(heap[child], heap[i]) then break end
            heap[i], heap[child] = heap[child], heap[i]; i = child
        end
    end
    return result
end

-- Unknown cells are optimistic unless knownOnly=true. Bounds are fixed for
-- the complete journey, so repeated replanning cannot expand them forever.
function pathfinding.find(start, goal, options)
    pathfinding.refreshTemporary()
    options = options or {}
    local bounds = options.bounds
    local function allowed(p)
        if excluded(p) then return false end
        if bounds then
            for _, axis in ipairs({ "x", "y", "z" }) do
                if p[axis] < bounds.min[axis] or p[axis] > bounds.max[axis] then return false end
            end
        end
        local state = cells[pathfinding.key(p)]
        return state ~= false and (not options.knownOnly or state == true)
    end
    if not allowed(goal) then return nil, "target_unreachable" end
    local distance=pathfinding.distance(start,goal)
    if distance==0 then return {} end
    if distance==1 then return {goal} end
    local first = { p = start, cost = 0, score = pathfinding.distance(start, goal) }
    local heap, costs = {}, { [pathfinding.key(start)] = 0 }
    push(heap, first)
    local expanded = 0
    while #heap > 0 do
        local node = pop(heap)
        local key = pathfinding.key(node.p)
        if node.cost == costs[key] then
            if pathfinding.distance(node.p, goal) == 0 then
                local reverse, route = {}, {}
                while node.parent do reverse[#reverse + 1] = node.p; node = node.parent end
                for i = #reverse, 1, -1 do route[#route + 1] = reverse[i] end
                return route
            end
            expanded = expanded + 1
            if expanded > (options.maxNodes or 6000) then return nil, "search_limit" end
            -- Yield to the CC event loop, without swallowing terminate.
            if expanded % 200 == 0 and sleep then sleep(0) end
            for _, d in ipairs(directions) do
                local p = { x = node.p.x + d.x, y = node.p.y + d.y, z = node.p.z + d.z }
                local nextKey = pathfinding.key(p)
                local cost = node.cost + 1
                if allowed(p) and (not costs[nextKey] or cost < costs[nextKey]) then
                    costs[nextKey] = cost
                    push(heap, { p = p, cost = cost, parent = node, score = cost + pathfinding.distance(p, goal) })
                end
            end
        end
    end
    return nil, "no_route"
end

function pathfinding.bounds(a, b, detour)
    local bounds = { min = {}, max = {} }
    for _, axis in ipairs({ "x", "y", "z" }) do
        bounds.min[axis] = math.min(a[axis], b[axis]) - detour
        bounds.max[axis] = math.max(a[axis], b[axis]) + detour
        -- A wall job has one fixed service opening. Include it in the
        -- bounded search so supplies remain reachable on every work layer.
        if avoid and avoid.walls and avoid.opening then
            bounds.min[axis]=math.min(bounds.min[axis],avoid.opening[axis]-1)
            bounds.max[axis]=math.max(bounds.max[axis],avoid.opening[axis]+1)
        end
    end
    return bounds
end

return pathfinding
