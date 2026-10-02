local env = ...
local test, eq, world = env.test, env.eq, env.world
local function setup(amount, name)
    local W = world()
    W.limit, W.fuel = 40000, 20000
    local c = env.configured({
        fuel = { x=2,y=0,z=0,direction=1,side="front" },
        output = { x=0,y=0,z=2,direction=2,side="front" },
        materials = { x=-2,y=0,z=0,direction=3,side="front" },
    })
    W.chests["3,0,0"] = { items = { { name="minecraft:coal", count=500 } } }
    W.chests["0,0,3"] = { items = {} }
    W.chests["-3,0,0"] = { items = amount == 0 and {} or { { name=name or "minecraft:stone",count=amount or 64 } } }
    return W, c
end
local a, b = {x=4,y=-1,z=0}, {x=6,y=-1,z=1}
test("floor plan requires one height and preserves first corner", function()
    local plan = require("floor_plan")
    local box = assert(plan.new(b,a))
    eq(box.volume,6)
    local first, stand = plan.cell(box,1,b)
    eq(first.x,6); eq(first.z,1); eq(stand.y,0)
    eq(plan.new(a,{x=6,y=0,z=1}),nil)
end)
test("floor builds rectangle from chest and returns home", function()
    local W = setup(6)
    W.selected = 7
    local ok, err, p = require("building").run(a,b,nil,0)
    assert(ok,err); eq(p.placed,6); eq(p.completed,6); eq(p.remaining,0)
    eq(#W.placements,6); eq(#W.digs,0); eq(W.x,0); eq(W.y,0); eq(W.z,0); eq(W.d,0)
    eq(W.selected,7); eq(#W.chests["-3,0,0"].items,0)
    eq(require("config").load().protectedItems["minecraft:stone"],nil)
    eq(p.startFuelTarget,nil)
    local first = W.placements[1]; eq(first.x,a.x); eq(first.y,a.y); eq(first.z,a.z)
end)
test("floor replenishes after a full stack without losing work position", function()
    local W = setup(90)
    local ok, err, p = require("building").run(a,{x=13,y=-1,z=8},nil,0)
    assert(ok,err); eq(p.placed,90); eq(#W.placements,90)
    local seen = {}
    for _, point in ipairs(W.placements) do
        local k = point.x .. "," .. point.y .. "," .. point.z
        assert(not seen[k]); seen[k]=true
    end
    eq(W.x,0); eq(W.z,0)
end)
test("floor skips matching blocks even with an empty source", function()
    local W = setup(0)
    for x=4,6 do for z=0,1 do local k=x..",-1,"..z; W.blocks[k]=true; W.blockNames[k]="minecraft:stone" end end
    local ok, err, p = require("building").run(a,b,"minecraft:stone",0)
    assert(ok,err); eq(p.skipped,6); eq(p.placed,0); eq(p.completed,6); eq(#W.digs,0)
end)
test("floor refuses to replace an existing different block", function()
    local W = setup(64)
    W.blocks["5,-1,0"],W.blockNames["5,-1,0"]=true,"minecraft:diamond_block"
    local ok, err, p = require("building").run(a,b,"minecraft:stone",0)
    eq(ok,false); assert(err:find("floor_occupied",1,true)); eq(p.completed,1); eq(p.placed,1)
    eq(W.blockNames["5,-1,0"],"minecraft:diamond_block"); eq(#W.digs,0); eq(p.returnedHome,true,p.returnError)
end)
test("floor uses partial source then stops with accurate counters", function()
    local W = setup(2)
    local ok, err, p = require("building").run(a,b,"minecraft:stone",0)
    eq(ok,false); eq(err,"materials_missing"); eq(p.placed,2); eq(p.completed,2); eq(p.remaining,4)
    eq(p.returnedHome,true); eq(#W.digs,0)
end)
test("floor waits at home and resumes the unfinished cell after refill", function()
    local W=setup(2)
    local waits=0
    local ok,err,p=require("building").run(a,b,"minecraft:stone",0,nil,function(name,progress)
        waits=waits+1
        eq(name,"minecraft:stone"); eq(progress.phase,"waiting_materials")
        eq(progress.completed,2); eq(progress.remaining,4); eq(progress.returnedHome,true)
        eq(W.x,0); eq(W.y,0); eq(W.z,0); eq(W.d,0)
        local packet=W.packets[#W.packets]
        eq(packet.activity,"waiting_materials"); eq(packet.progress.completed,2)
        W.chests["-3,0,0"].items={{name=name,count=4}}
        return true
    end)
    assert(ok,err); eq(waits,1); eq(p.placed,6); eq(p.completed,6); eq(p.returnedHome,true)
    eq(#W.placements,6)
    local seen={}
    for _,point in ipairs(W.placements) do
        local k=point.x..","..point.y..","..point.z
        assert(not seen[k]); seen[k]=true
    end
end)
test("floor empty refill confirmation waits again at home", function()
    local W=setup(2); local waits=0
    local ok,err,p=require("building").run(a,b,"minecraft:stone",0,nil,function(name,progress)
        waits=waits+1
        eq(W.x,0); eq(W.y,0); eq(W.z,0); eq(progress.completed,2)
        if waits==2 then W.chests["-3,0,0"].items={{name=name,count=4}} end
        assert(waits<=2)
        return true
    end)
    assert(ok,err); eq(waits,2); eq(p.placed,6); eq(p.completed,6)
end)
test("floor user can cancel while waiting at home", function()
    local W=setup(2); local waits=0
    local ok,err,p=require("building").run(a,b,"minecraft:stone",0,nil,function(_,progress)
        waits=waits+1; eq(W.x,0); eq(W.z,0); eq(progress.completed,2)
        return false
    end)
    eq(ok,false); eq(err,"cancelled_by_user"); eq(waits,1)
    eq(p.placed,2); eq(p.remaining,4); eq(p.returnedHome,true)
    eq(require("config").load().protectedItems["minecraft:stone"],nil)
    eq(#require("config").load().fuelSlots,0)
end)
test("floor failed placement never counts an unfinished cell", function()
    local W = setup(64); W.placeFailAt="5,-1,0"
    local ok, err, p = require("building").run(a,b,"minecraft:stone",0)
    eq(ok,false); assert(err:find("place_failed",1,true)); eq(p.completed,1); eq(p.placed,1); eq(p.returnedHome,true)
end)
test("floor walking obstacle stops without digging or drifting", function()
    local W = setup(64); W.blocks["5,0,0"]=true; W.blocks["5,-2,0"]=true
    local ok, err, p = require("building").run(a,b,"minecraft:stone",0)
    eq(ok,false); assert(err:find("floor_travel_failed",1,true)); eq(p.completed,1); eq(#W.digs,0); eq(p.returnedHome,true)
end)
test("floor uses selected inventory sample and loads a batch before entry", function()
    local W=setup(100)
    W.slots[1]={name="minecraft:stone",count=1}
    local original=turtle.placeDown; local firstCount
    turtle.placeDown=function()
        firstCount=firstCount or require("inventory").count("minecraft:stone")
        return original()
    end
    local ok,err,p=require("building").run(a,b,nil,0)
    assert(ok,err); eq(firstCount,6); eq(p.placed,6)
    eq(W.chests["-3,0,0"].items[1].count,95)
end)
test("floor builds from underneath without crossing its own plane", function()
    local W,c=setup(64)
    W.y=-2
    c.start.y,c.home.y=-2,-2
    for _,s in pairs(c.stations) do s.y=-2 end
    assert(require("config").save(c))
    W.chests["3,-2,0"],W.chests["3,0,0"]=W.chests["3,0,0"],nil
    W.chests["-3,-2,0"],W.chests["-3,0,0"]=W.chests["-3,0,0"],nil
    W.chests["0,-2,3"],W.chests["0,0,3"]=W.chests["0,0,3"],nil
    for x=4,6 do for z=0,1 do W.blocks[x..",0,"..z]=true end end
    local ok,err,p=require("building").run(a,b,"minecraft:stone",0)
    assert(ok,err); eq(p.placed,6); eq(W.y,-2); eq(#W.digs,0)
end)
test("floor switches below when the first upper stand is obstructed", function()
    local W=setup(64); W.blocks["4,0,0"]=true
    local ok,err,p=require("building").run(a,b,"minecraft:stone",0)
    assert(ok,err); eq(p.placed,6); eq(p.returnedHome,true); eq(#W.digs,0)
end)
test("floor 4000 block fuel estimate uses inventory capacity and skips refuel at 30k", function()
    local W=setup(5000); W.fuel=30000
    local original=turtle.placeDown
    local fuelAtFirst,itemsAtFirst
    turtle.placeDown=function()
        fuelAtFirst=fuelAtFirst or W.fuel
        itemsAtFirst=itemsAtFirst or require("inventory").count("minecraft:stone")
        return original()
    end
    local stopped=false
    env.navReady().setRuntime(nil,function()
        local p=require("telemetry").getProgress()
        if p and p.completed==1 and not stopped then stopped=true; return false,"test_stop" end
        return true
    end)
    local ok,err,p=require("building").run(a,{x=83,y=-1,z=49},"minecraft:stone",0)
    eq(ok,false); eq(p.total,4000); eq(p.startFuelTarget,nil); assert(p.startFuelRequired<30000)
    eq(W.refuelCounts,nil); assert(fuelAtFirst<30000); eq(itemsAtFirst,960); eq(p.returnedHome,true)
end)
test("floor rejects chest in placement and walking layers", function()
    setup(64)
    local c = require("config").load()
    c.stations.materials = {x=4,y=0,z=-1,direction=2,side="front"}; assert(require("config").save(c))
    local box,err = require("building").validateArea(a,b)
    eq(box,nil); eq(err,"station_inside_floor:materials")
end)
test("floor consumes existing inventory and returns leftovers to source", function()
    local W = setup(0)
    W.slots[5]={name="minecraft:stone",count=10}
    local ok, err, p = require("building").run(a,b,"minecraft:stone",0)
    assert(ok,err); eq(p.placed,6); eq(require("inventory").count("minecraft:stone"),0)
    eq(W.chests["-3,0,0"].items[1].count,4)
end)
test("floor never burns wooden construction material and restores settings", function()
    local W = setup(64,"minecraft:oak_planks"); W.fuel=100
    W.slots[1]={name="minecraft:oak_planks",count=6}
    local previous = turtle.refuel
    local burned=0
    turtle.refuel=function(n)
        local item=W.slots[W.selected]
        if item and item.name=="minecraft:oak_planks" then
            if n==0 then return true end
            burned=burned+1; return false
        end
        return previous(n)
    end
    local ok,err,p = require("building").run(a,b,"minecraft:oak_planks",0)
    assert(ok,err); eq(burned,0); eq(p.placed,6); assert(p.startFuelTarget)
    eq(require("config").load().protectedItems["minecraft:oak_planks"],nil)
end)
test("floor telemetry preserves placement counters through navigation", function()
    setup(64)
    local ok,err= require("building").run(a,b,"minecraft:stone",0); assert(ok,err)
    local t=require("telemetry"); t.setActivity("idle")
    local p=world().packets[#world().packets].progress
    eq(p.taskType,"floor"); eq(p.placed,6); eq(p.remaining,0)
end)
test("floor keeps reserved fuel slot empty while unloading other items", function()
    local W,c=setup(64); c.fuelSlots={16}; assert(require("config").save(c))
    for slot=1,15 do W.slots[slot]={name="minecraft:dirt",count=64} end
    local ok,err,p=require("building").run(a,b,"minecraft:stone",0)
    assert(ok,err); eq(p.placed,6); eq(W.slots[16],nil); assert(#W.chests["0,0,3"].items>0)
end)
test("floor full material batch retains a slot for mid-job refuelling", function()
    local W=setup(5000)
    local original=turtle.placeDown
    local placements=0
    turtle.placeDown=function()
        local ok,err=original()
        if ok then placements=placements+1; if placements==1 then W.fuel=26 end end
        return ok,err
    end
    local stopped=false
    env.navReady().setRuntime(nil,function()
        local p=require("telemetry").getProgress()
        if p and p.completed==2 and not stopped then stopped=true; return false,"test_stop" end
        return true
    end)
    local ok,err,p=require("building").run(a,{x=43,y=-1,z=24},"minecraft:stone",0)
    eq(ok,false); eq(err,"test_stop"); eq(p.completed,2); assert(W.refuelCounts and #W.refuelCounts>0)
    eq(p.returnedHome,true); eq(#require("config").load().fuelSlots,0)
end)
test("floor stop checkpoint retreats without another placement", function()
    setup(64); local nav=env.navReady(); local stopped=false
    nav.setRuntime(nil,function()
        local p=require("telemetry").getProgress()
        if not stopped and p and p.completed==2 then stopped=true; return false,"stopped_by_controller" end
        return true
    end)
    local ok,err,p=require("building").run(a,b,"minecraft:stone",0)
    eq(ok,false); eq(err,"stopped_by_controller"); eq(p.completed,2); eq(p.placed,2); eq(p.returnedHome,true)
    eq(require("config").load().protectedItems["minecraft:stone"],nil)
end)
test("floor navigation exclusion survives resets and is restored after failure", function()
    local W=setup(64); W.placeFailAt="5,-1,0"
    local paths=require("pathfinding")
    local previous={min={x=100,y=100,z=100},max={x=101,y=101,z=101}}
    paths.setAvoid(previous)
    local ok,err,p=require("building").run(a,b,"minecraft:stone",0)
    eq(ok,false); eq(p.returnedHome,true); eq(paths.setAvoid(nil),previous)
    eq(W.blockNames["4,-1,0"],"minecraft:stone")
end)
test("fleet dispatches floor segments with required material station", function()
    local W,c = setup(64)
    local ctl=require("fleet_controller").new({})
    local model=require("fleet_model")
    for _,id in ipairs({21,22}) do
        ctl.handle(id,{version=1,id=id,kind="status",status="idle",dock={x=0,y=0,z=-id,direction=0}},model.protocol)
    end
    local ok,err=ctl.start(a,b,{21,22},c.stations,nil,nil,{kind="floor",block="minecraft:stone"})
    assert(ok,err)
    eq(ctl.state.job.kind,"floor"); eq(ctl.state.job.total,6)
    local totals=0
    for _,task in pairs(ctl.state.job.tasks) do
        eq(task.assignment.kind,"floor"); eq(task.assignment.block,"minecraft:stone"); totals=totals+task.total
    end
    eq(totals,6)
    local task=ctl.state.job.tasks[21]
    model.updateProgress(task,{completed=task.total,placed=task.total,skipped=0,taskType="floor"})
    model.updateProgress(task,{completed=0,placed=0,taskType="floor"})
    eq(task.progress.placed,task.total); eq(ctl.snapshot().summary.placed,task.total)
    local assignment=require("fleet_store").copy(task.assignment); assignment.stations.materials=nil
    local settings,invalid=require("fleet_task").settings(assignment,W)
    eq(settings,nil)
    -- Use a valid dock, to verify the actual materials requirement.
    settings,invalid=require("fleet_task").settings(assignment,{x=0,y=0,z=-21,direction=0})
    eq(settings,nil); eq(invalid,"station_missing:materials")
end)
