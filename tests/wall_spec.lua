local env=...
local test,eq,world=env.test,env.eq,env.world
local a,b={x=4,y=0,z=4},{x=6,y=2,z=6}
local function setup(amount)
    local W=world(); W.limit,W.fuel=40000,20000
    env.configured({fuel={x=2,y=0,z=0,direction=1,side="front"},
        output={x=0,y=0,z=2,direction=2,side="front"},
        materials={x=-2,y=0,z=0,direction=3,side="front"}})
    W.chests["3,0,0"]={items={{name="minecraft:coal",count=500}}}
    W.chests["0,0,3"]={items={}}
    W.chests["-3,0,0"]={items=amount==0 and {} or {{name="minecraft:stone",count=amount or 64}}}
    return W
end
local function key(p) return p.x..","..p.y..","..p.z end
test("fleet wall segments cover each requested block once and share a single last opening",function()
    local plan,model=require("wall_plan"),require("fleet_model")
    for _,corners in ipairs({false,true}) do
        for _,x in ipairs({4,10}) do for _,z in ipairs({4,12}) do for _,y in ipairs({0,3}) do
            local first={x=x,y=y,z=z}
            local last={x=x==4 and 10 or 4,y=3-y,z=z==4 and 12 or 4}
            for _,count in ipairs({1,2,3,7,24}) do
                local parts,err,whole=model.splitWalls(first,last,count,{includeCorners=corners})
                assert(parts,err)
                local seen,total,closers={},0,0
                for _,part in ipairs(parts) do
                    local box=assert(plan.new(part.a,part.b,part.wallOptions))
                    eq(key(box.opening),key(whole.opening)); eq(box.volume,part.total)
                    if box.closeOpening then
                        closers=closers+1; eq(key(plan.cell(box,box.volume,part.a)),key(whole.opening))
                    end
                    for i=1,box.volume do
                        local p=assert(plan.cell(box,i,part.a)); assert(plan.isWall(whole,p))
                        assert(not seen[key(p)],"overlap: "..key(p)); seen[key(p)]=true; total=total+1
                    end
                end
                eq(closers,1); eq(total,whole.volume)
                for i=1,whole.volume do assert(seen[key(plan.cell(whole,i,first))]) end
            end
        end end end
    end
end)

test("fleet wall validation rejects malformed segments and narrow shared interiors",function()
    local plan,model=require("wall_plan"),require("fleet_model")
    for _,range in ipairs({{first=0,last=2},{first=2,last=1},{first=1,last=999},{first=1.5,last=2}}) do
        local box,err=plan.new(a,b,{includeCorners=false,segment=range})
        eq(box,nil); eq(err,"invalid_wall_segment")
    end
    local parts,err=model.splitWalls(a,b,2)
    eq(parts,nil); eq(err,"fleet_walls_need_two_blocks_of_interior_width")
end)
test("wall plan without corners covers every face cell once for all starting corners",function()
    local plan=require("wall_plan")
    for _,size in ipairs({{3,3},{3,5},{5,3},{4,7}}) do
        local low,high={x=4,y=0,z=4},{x=3+size[1],y=2,z=3+size[2]}
        for _,x in ipairs({low.x,high.x}) do for _,z in ipairs({low.z,high.z}) do
            for _,y in ipairs({0,2}) do
                local first={x=x,y=y,z=z}
                local other={x=x==low.x and high.x or low.x,y=2-y,z=z==low.z and high.z or low.z}
                local box=assert(plan.new(first,other,{includeCorners=false}))
                eq(box.volume,(2*(size[1]+size[2])-8)*3)
                local seen={}
                for i=1,box.volume do
                    local p=assert(plan.cell(box,i,first)); assert(not seen[key(p)]); seen[key(p)]=true
                    assert(plan.isWall(box,p))
                    assert(not ((p.x==low.x or p.x==high.x) and (p.z==low.z or p.z==high.z)))
                end
                for px=low.x,high.x do for py=0,2 do for pz=low.z,high.z do
                    local p={x=px,y=py,z=pz}
                    local corner=(px==low.x or px==high.x) and (pz==low.z or pz==high.z)
                    eq(seen[key(p)]==true,plan.isWall(box,p) and not corner)
                end end end
                eq(key(plan.cell(box,box.volume,first)),key(box.opening))
            end
        end end
    end
end)
test("walls without corners work underground through one passage and refill without touching corner columns",function()
    local W=setup(5); local waits=0
    local plan=require("wall_plan"); local options={includeCorners=false}
    local box=assert(plan.new(a,b,options)); eq(box.volume,12)
    -- Solid earth around the room; only the service doorway has exterior access.
    for x=3,7 do for y=-1,3 do for z=3,7 do
        if x~=5 or z~=5 or y<0 or y>2 then
            local k=x..","..y..","..z; W.blocks[k]=true; W.blockNames[k]="minecraft:dirt"
        end
    end end end
    W.blocks["3,1,5"],W.blockNames["3,1,5"]=nil,nil
    local place=turtle.place
    turtle.place=function()
        local p=require("navigation").getPosition()
        local target=require("position").offset(p,p.direction,"front")
        if key(target)~=key(box.opening) then
            assert(require("cuboid").contains(box,p)); assert(not plan.isWall(box,p))
        else eq(#W.placements,11) end
        return place()
    end
    local ok,err,p=require("building").runWalls(a,b,"minecraft:stone",0,function(name,progress)
        waits=waits+1; eq(progress.completed,5); eq(W.x,0); eq(W.y,0); eq(W.z,0)
        eq(W.blocks[key(box.opening)],nil)
        W.chests["-3,0,0"].items={{name=name,count=64}}; return true
    end,options)
    assert(ok,err); eq(waits,1); eq(p.total,12); eq(p.placed,12); eq(p.dug,12); eq(p.returnedHome,true)
    for _,point in ipairs(W.digs) do
        assert(plan.isWall(box,point))
        assert(not ((point.x==4 or point.x==6) and (point.z==4 or point.z==6)))
    end
    for x=3,7 do for y=-1,3 do for z=3,7 do
        local point={x=x,y=y,z=z}; local k=key(point)
        local corner=(x==4 or x==6) and (z==4 or z==6)
        if plan.isWall(box,point) and not corner then eq(W.blockNames[k],"minecraft:stone")
        elseif k~="3,1,5" and (x~=5 or z~=5 or y<0 or y>2) then eq(W.blockNames[k],"minecraft:dirt") end
    end end end
end)
test("wall options reject invalid corner selections",function()
    for _,options in ipairs({true,{},{includeCorners="no"}}) do
        local box,err=require("wall_plan").new(a,b,options)
        eq(box,nil); eq(err,"invalid_wall_options")
    end
end)
test("walls without corners never fall back to an outside approach when an inner face is blocked",function()
    local W=setup(64); W.x,W.y,W.z=5,1,5
    local nav=require("navigation"); local start={x=5,y=1,z=5,direction=0}
    assert(nav.init(0))
    require("supplies").ensure=function() return true end
    require("supplies").navigationOptions=function() return {} end
    local calls={}
    nav.moveToCoord=function(x,y,z)
        calls[#calls+1]={x=x,y=y,z=z}
        if x==start.x and y==start.y and z==start.z then return true end
        eq(x,5); eq(y,0); eq(z,5)
        return false,"target_unreachable"
    end
    local box=assert(require("wall_plan").new(a,b,{includeCorners=false}))
    local side,err=require("wall_access").new(box).reach({x=4,y=0,z=5})
    eq(side,nil); eq(err,"wall_unreachable:target_unreachable"); eq(#calls,3)
end)
test("wall plan counts corners once, covers four faces and preserves reversed first corner",function()
    local plan=require("wall_plan")
    for _,first in ipairs({a,b}) do
        local box=assert(plan.new(a,b)); eq(box.volume,24)
        local seen={}
        for i=1,box.volume do
            local p=plan.cell(box,i,first); assert(not seen[key(p)]); seen[key(p)]=true
            assert(p.x==4 or p.x==6 or p.z==4 or p.z==6)
            assert(p.y>=0 and p.y<=2)
        end
        eq(key(plan.cell(box,1,first)),key(first))
        eq(seen["5,0,5"],nil); eq(seen["5,2,5"],nil)
    end
end)
test("walls replace only the four faces and preserve the interior, floor and ceiling",function()
    local W=setup(64)
    for x=4,6 do for y=0,2 do for z=4,6 do
        local k=x..","..y..","..z; W.blocks[k]=true; W.blockNames[k]="minecraft:dirt"
    end end end
    W.blocks["4,0,4"],W.blockNames["4,0,4"]=true,"minecraft:stone"
    local ok,err,p=require("building").runWalls(a,b,"minecraft:stone",0)
    assert(ok,err); eq(p.completed,24); eq(p.remaining,0); eq(p.placed,23); eq(p.skipped,1); eq(p.dug,23)
    for _,point in ipairs(W.digs) do assert(point.x==4 or point.x==6 or point.z==4 or point.z==6) end
    for y=0,2 do eq(W.blockNames["5,"..y..",5"],"minecraft:dirt") end
    eq(W.x,0); eq(W.y,0); eq(W.z,0); eq(W.d,0); eq(W.lostDrops,0)
    assert(#W.chests["0,0,3"].items>0)
end)
test("wall perimeter covers narrow rectangles and every possible first corner",function()
    local plan=require("wall_plan")
    for _,size in ipairs({{3,3},{3,5},{5,3},{4,7}}) do
        local low,high={x=4,y=0,z=4},{x=3+size[1],y=2,z=3+size[2]}
        local box=assert(plan.new(low,high))
        for _,x in ipairs({low.x,high.x}) do for _,z in ipairs({low.z,high.z}) do
            for _,y in ipairs({0,2}) do
                local first={x=x,y=y,z=z}; local seen={}
                for i=1,box.volume do
                    local point=plan.cell(box,i,first)
                    assert(require("cuboid").contains(box,point)); assert(not seen[key(point)]); seen[key(point)]=true
                    assert(point.x==low.x or point.x==high.x or point.z==low.z or point.z==high.z)
                end
                eq(key(plan.cell(box,1,first)),key(first))
            end
        end end
    end
end)
test("walls unload mixed demolition drops during work without losing items or touching outside blocks",function()
    local W=setup(200)
    local c=require("config").load(); c.fuelSlots={16}; assert(require("config").save(c))
    W.slots[16]={name="minecraft:coal",count=4}
    local last={x=12,y=2,z=15}
    local plan=require("wall_plan"); local box=assert(plan.new(a,last))
    for i=1,box.volume do
        local k=key(plan.cell(box,i,a)); W.blocks[k]=true; W.blockNames[k]="minecraft:dirt"
        W.drops[k]="test:drop_"..i
    end
    local ok,err,p=require("building").runWalls(a,last,"minecraft:stone",0)
    assert(ok,err); eq(p.completed,box.volume); eq(p.dug,box.volume); eq(p.placed,box.volume); eq(W.lostDrops,0)
    local dropped=0; for _,item in ipairs(W.chests["0,0,3"].items) do dropped=dropped+item.count end
    eq(dropped,box.volume); eq(W.x,0); eq(W.z,0); eq(W.slots[16].name,"minecraft:coal"); eq(W.slots[16].count,4)
end)
test("walls wait for another turtle without digging into it",function()
    local W=setup(64); W.blocks["4,0,4"]=true; W.blockNames["4,0,4"]="computercraft:turtle_advanced"
    local waits=0
    sleep=function(seconds)
        W.ticks=W.ticks+seconds
        if seconds==0.5 then
            waits=waits+1; eq(#W.digs,0)
            if waits==3 then W.blocks["4,0,4"],W.blockNames["4,0,4"]=nil,nil end
        end
    end
    local ok,err,p=require("building").runWalls(a,b,"minecraft:stone",0)
    assert(ok,err); eq(waits,3); eq(p.placed,24)
end)
test("walls do not remove blocks when replacement material is missing",function()
    local W=setup(0); W.blocks["4,0,4"]=true; W.blockNames["4,0,4"]="minecraft:dirt"
    local ok,err,p=require("building").runWalls(a,b,"minecraft:stone",0)
    eq(ok,false); eq(err,"materials_missing"); eq(#W.digs,0); eq(p.returnedHome,true)
    eq(W.blockNames["4,0,4"],"minecraft:dirt")
end)
test("walls verify the output inventory before demolishing the first block",function()
    local W=setup(64); W.chests["0,0,3"]=nil
    W.blocks["4,0,4"]=true; W.blockNames["4,0,4"]="minecraft:dirt"
    local ok,err,p=require("building").runWalls(a,b,"minecraft:stone",0)
    eq(ok,false); eq(err,"station_inventory_missing"); eq(#W.digs,0); eq(#W.placements,0); eq(p.returnedHome,true)
end)
test("walls wait at home for replacement material and resume",function()
    local W=setup(2); local waits=0
    local ok,err,p=require("building").runWalls(a,b,"minecraft:stone",0,function(name,progress)
        waits=waits+1; eq(progress.phase,"waiting_materials"); eq(W.x,0); eq(W.y,0); eq(W.z,0)
        W.chests["-3,0,0"].items={{name=name,count=64}}; return true
    end)
    assert(ok,err); eq(waits,1); eq(p.placed,24); eq(p.completed,24)
end)
test("walls place face blocks from the interior, corners outside and close the opening last",function()
    local W=setup(64)
    local plan=require("wall_plan"); local box=assert(plan.new(a,b))
    local cuboid=require("cuboid"); local position=require("position")
    local place=turtle.place; local interiorCount=0
    turtle.place=function()
        local p=require("navigation").getPosition(); local target=position.offset(p,p.direction,"front")
        assert(plan.isWall(box,target)); assert(not plan.isWall(box,p),"Turtle must not stand in a future wall")
        local corner=(target.x==box.min.x or target.x==box.max.x) and (target.z==box.min.z or target.z==box.max.z)
        if key(target)==key(box.opening) then
            eq(#W.placements,box.volume-1); eq(cuboid.contains(box,p),false)
        elseif not corner then
            assert(cuboid.contains(box,p),"Ordinary wall blocks should be placed from inside")
            interiorCount=interiorCount+1
        else eq(cuboid.contains(box,p),false) end
        return place()
    end
    local ok,err,p=require("building").runWalls(a,b,"minecraft:stone",0)
    assert(ok,err); eq(interiorCount,11); eq(p.placed,24)
    eq(key(W.placements[#W.placements]),key(box.opening)); eq(W.x,0); eq(W.z,0)
end)
test("walls can refill from inside through the unfinished opening and still return home",function()
    local W=setup(14); local waits=0
    local plan=require("wall_plan"); local box=assert(plan.new(a,b))
    for i=1,box.volume do local k=key(plan.cell(box,i,a)); W.blocks[k]=true; W.blockNames[k]="minecraft:dirt" end
    local ok,err,p=require("building").runWalls(a,b,"minecraft:stone",0,function(name,progress)
        waits=waits+1; eq(W.x,0); eq(W.y,0); eq(W.z,0)
        eq(progress.completed,14); eq(W.blocks[key(box.opening)],nil)
        W.chests["-3,0,0"].items={{name=name,count=64}}; return true
    end)
    assert(ok,err); eq(waits,1); eq(p.placed,24); eq(p.dug,24); eq(p.returnedHome,true)
    eq(W.blockNames[key(box.opening)],"minecraft:stone")
end)
test("walls reject a station or home enclosed by the requested room",function()
    setup(64)
    eq(require("building").validateArea({x=-4,y=-1,z=-1},{x=4,y=1,z=4},"walls"),nil)
end)
test("walls do not dig containers, fluids or unbreakable blocks",function()
    for _,kind in ipairs({"water","chest","bedrock"}) do
        local W=setup(64); W.chests["4,0,4"]=nil
        W.blocks["4,0,4"]=true; W.blockNames["4,0,4"]="minecraft:"..kind
        if kind=="chest" then W.chests["4,0,4"]={items={}} end
        if kind=="bedrock" then W.unbreakable["4,0,4"]=true end
        local ok,err=require("building").runWalls(a,b,"minecraft:stone",0)
        eq(ok,false); eq(#W.digs,0)
        assert(err:find(kind=="water" and "fluid_in_area" or (kind=="chest" and "inventory_in_area" or "dig_failed"),1,true))
    end
end)
