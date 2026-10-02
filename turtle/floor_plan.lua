-- Coordinates describe floor blocks; the turtle walks one block above them.
local cuboid = require("cuboid")
local plan = {}
function plan.new(a, b)
    local box, err = cuboid.new(a, b)
    if not box then return nil, err end
    if box.size.y ~= 1 then return nil, "floor_corners_need_same_y" end
    if box.max.y >= 30000000 then return nil, "floor_height_out_of_range" end
    return box
end
function plan.protected(box)
    return { min = { x = box.min.x, y = box.min.y - 1, z = box.min.z },
        max = { x = box.max.x, y = box.max.y + 1, z = box.max.z } }
end
function plan.cell(box, index, first)
    local block, err = cuboid.cell(box, index, first)
    if not block then return nil, err end
    return block, { x = block.x, y = block.y + 1, z = block.z }
end
return plan
