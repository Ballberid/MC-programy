local floors=require("floor_plan")
local plan={}
function plan.new(a,b)
    local box,err=floors.new(a,b)
    if not box then return nil,err end
    if box.min.y<=-30000000 then return nil,"ceiling_height_out_of_range" end
    return box
end
plan.protected=floors.protected
function plan.cell(box,index,first)
    local block,err=floors.cell(box,index,first)
    if not block then return nil,err end
    return block,{x=block.x,y=block.y-1,z=block.z}
end
return plan
