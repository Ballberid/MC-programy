local pathfinding = {}
local cells = {}
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
    cells[pathfinding.key(p)] = free
end

function pathfinding.clear()
    cells = {}
end

function pathfinding.forgetBlocked()
    for key, free in pairs(cells) do if free == false then cells[key] = nil end end
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
    options = options or {}
    local bounds = options.bounds
    local function allowed(p)
        if bounds then
            for _, axis in ipairs({ "x", "y", "z" }) do
                if p[axis] < bounds.min[axis] or p[axis] > bounds.max[axis] then return false end
            end
        end
        local state = cells[pathfinding.key(p)]
        return state ~= false and (not options.knownOnly or state == true)
    end
    if not allowed(goal) then return nil, "target_unreachable" end
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
    end
    return bounds
end

return pathfinding
