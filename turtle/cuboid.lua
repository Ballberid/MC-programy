local config = require("config")
local cuboid = {}

function cuboid.new(a, b)
    if not config.isPoint(a) or not config.isPoint(b) then return nil, "invalid_corners" end
    local box = { min = {}, max = {}, size = {}, volume = 1 }
    for _, axis in ipairs({ "x", "y", "z" }) do
        box.min[axis] = math.min(a[axis], b[axis])
        box.max[axis] = math.max(a[axis], b[axis])
        box.size[axis] = box.max[axis] - box.min[axis] + 1
        box.volume = box.volume * box.size[axis]
    end
    if box.volume > 1000000 then return nil, "area_too_large" end
    return box
end

function cuboid.contains(box, p)
    for _, axis in ipairs({ "x", "y", "z" }) do
        if p[axis] < box.min[axis] or p[axis] > box.max[axis] then return false end
    end
    return true
end

-- Choose the nearest upper corner. No list of a million cells in memory.
function cuboid.entry(box, p)
    return {
        x = math.abs(p.x - box.min.x) <= math.abs(p.x - box.max.x) and box.min.x or box.max.x,
        y = box.max.y,
        z = math.abs(p.z - box.min.z) <= math.abs(p.z - box.max.z) and box.min.z or box.max.z,
    }
end

-- All exterior neighbours of the upper corners, ordered by distance from
-- the turtle. Include both sides for a box only one block wide/deep.
function cuboid.approaches(box, from)
    local approaches, seen = {}, {}
    local function add(cell, stand)
        if cuboid.contains(box, stand) then return end
        local key = stand.x .. "," .. stand.y .. "," .. stand.z .. ":" .. cell.x .. "," .. cell.z
        if seen[key] then return end
        seen[key] = true
        approaches[#approaches + 1] = {
            cell = cell, stand = stand, order = #approaches + 1,
            distance = math.abs(stand.x - from.x) + math.abs(stand.y - from.y) + math.abs(stand.z - from.z),
        }
    end
    for _, x in ipairs({ box.min.x, box.max.x }) do
        for _, z in ipairs({ box.min.z, box.max.z }) do
            local cell = { x = x, y = box.max.y, z = z }
            add(cell, { x = x, y = cell.y + 1, z = z })
            for _, d in ipairs({ -1, 1 }) do
                add(cell, { x = x + d, y = cell.y, z = z })
                add(cell, { x = x, y = cell.y, z = z + d })
            end
        end
    end
    table.sort(approaches, function(a, b)
        if a.distance == b.distance then return a.order < b.order end
        return a.distance < b.distance
    end)
    return approaches
end

-- Adjacent snake cells on each layer; alternate the complete layer traversal
-- so the next layer starts directly below the end of the previous one.
function cuboid.cell(box, index, entry)
    if index < 1 or index > box.volume or index % 1 ~= 0 then return nil, "invalid_cell_index" end
    local layerSize = box.size.x * box.size.z
    local layer = math.floor((index - 1) / layerSize)
    local offset = (index - 1) % layerSize
    if layer % 2 == 1 then offset = layerSize - 1 - offset end
    local row = math.floor(offset / box.size.x)
    local column = offset % box.size.x
    if row % 2 == 1 then column = box.size.x - 1 - column end
    return {
        x = entry.x == box.min.x and box.min.x + column or box.max.x - column,
        y = box.max.y - layer,
        z = entry.z == box.min.z and box.min.z + row or box.max.z - row,
    }
end

return cuboid
