local env = ...
local test, eq, world = env.test, env.eq, env.world
local function dock() return { x = 0, y = 0, z = 0, direction = 0 } end
local function stations()
    return { fuel = { x = 2, y = 0, z = 2, direction = 1, side = "front" },
        output = { x = -2, y = 0, z = 2, direction = 3, side = "front" } }
end
local function assignment(id)
    return { id = id or "job:1", jobId = "job", a = { x = 8, y = 4, z = 2 },
        b = { x = 11, y = 2, z = 5 }, stations = stations() }
end
local function tunnel()
    return { x = 0, z = 0, floors = {
        base = { exit = { x = 2, y = 0, z = 0 } },
        upper = { exit = { x = 2, y = 4, z = 0 } },
    } }
end
local function controllerWithWorkers()
    local c = require("fleet_controller").new(require("fleet_settings").defaults())
    local model = require("fleet_model")
    for _, id in ipairs({ 41, 42, 43 }) do
        c.handle(id, { version = 1, id = id, kind = "status", status = "idle", dock = dock(), fuel = 1000 }, model.protocol)
    end
    return c, model
end

local function mixedJobs()
    local c,m=controllerWithWorkers(); local first=assignment()
    assert(c.start(first.a,first.b,{41},first.stations))
    local digging=c.state.job
    local st=stations(); st.materials={x=4,y=0,z=2,direction=1,side="front"}
    assert(c.start({x=20,y=-1,z=2},{x=23,y=-1,z=5},{42},st,nil,nil,{kind="floor"}))
    return c,m,digging,c.state.job,st
end
test("multiple jobs route progress, retries and controls independently across controller restarts",function()
    local c,m,digging,building=mixedJobs()
    for _,entry in ipairs({{41,digging,8},{42,building,3}}) do
        local id,job,n=entry[1],entry[2],entry[3]
        c.handle(id,{version=1,id=id,kind="status",status="running",taskId=job.tasks[id].id,dock=dock(),
            progress={completed=n,taskType=job.kind}},m.protocol)
    end
    eq(digging.tasks[41].progress.completed,8); eq(building.tasks[42].progress.completed,3)
    eq(c.snapshot().summary.completed,11); eq(c.snapshot().summary.kind,"mixed"); eq(#c.snapshot().jobs,2)
    local groups=require("fleet_display").groups(c.snapshot())
    eq(groups[1].total,16); eq(groups[1].completed,3); eq(groups[2].total,48); eq(groups[2].completed,8)
    c.control("pause",nil,digging.id)
    eq(c.state.pendingControls[41].action,"pause"); eq(c.state.pendingControls[42],nil)
    c.handle(42,{version=1,id=42,kind="lock",taskId=building.tasks[42].id,resource="station:2,0,2",request="fuel42"},m.protocol)
    c.save()
    local restarted=require("fleet_controller").new(require("fleet_settings").defaults())
    eq(restarted.snapshot().summary.completed,11); eq(#restarted.snapshot().jobs,2)
    eq(restarted.snapshot().serviceOwner,42); eq(restarted.state.pendingControls[41].action,"pause")
    restarted.handle(41,{version=1,id=41,message="working",context={taskId=digging.tasks[41].id},progress={completed=9}},m.telemetryProtocol)
    eq(restarted.state.jobs[digging.id].tasks[41].progress.completed,9)
    eq(restarted.state.jobs[building.id].tasks[42].progress.completed,3)
    local saved=require("fleet_store").load("data/fleet-state.txt",{})
    eq(saved.version,2); eq(saved.job,nil); assert(saved.jobs[digging.id])
end)
test("new jobs can start while another worker reserves service but cannot steal that worker",function()
    local c,m=controllerWithWorkers(); local job=assignment()
    assert(c.start(job.a,job.b,{41},job.stations)); local id=c.state.job.tasks[41].id
    c.handle(41,{version=1,id=41,kind="lock",taskId=id,resource="station:2,0,2",request="fuel41"},m.protocol)
    assert(c.start({x=20,y=0,z=0},{x=21,y=0,z=1},{42},job.stations))
    eq(c.snapshot().serviceOwner,41)
    local ok,err=c.start({x=30,y=0,z=0},{x=31,y=0,z=1},{41},job.stations)
    eq(ok,false); eq(err,"worker_unavailable:41")
end)
test("overlap protection includes building access height and existing job infrastructure",function()
    local c,m,digging,building,st=mixedJobs()
    local count=#c.snapshot().jobs
    local ok,err=c.start({x=20,y=0,z=2},{x=21,y=0,z=3},{43},st)
    eq(ok,false); assert(err:find("job_area_conflict",1,true)); eq(#c.snapshot().jobs,count)
    local remote={fuel={x=-12,y=0,z=2,direction=1,side="front"},output={x=-14,y=0,z=2,direction=3,side="front"}}
    ok,err=c.start({x=2,y=0,z=2},{x=3,y=0,z=2},{43},remote)
    eq(ok,false); assert(err:find("job_infrastructure_conflict",1,true))
    local inside={fuel={x=9,y=3,z=3,direction=1,side="front"},output=st.output}
    ok,err=c.start({x=30,y=0,z=0},{x=31,y=0,z=1},{43},inside)
    eq(ok,false); assert(err:find("job_infrastructure_conflict",1,true))
    eq(c.state.workers[43].status,"idle")
end)
test("reassigned workers ignore delayed messages and old job controls cannot affect the new task",function()
    local c,m,digging,building,st=mixedJobs()
    local old=digging.tasks[41].id
    c.handle(41,{version=1,id=41,kind="status",status="complete",taskId=old,dock=dock(),progress={completed=48}},m.protocol)
    assert(c.start({x=30,y=0,z=0},{x=31,y=0,z=1},{41},st))
    local current=c.state.workers[41].taskId
    c.handle(41,{version=1,id=41,kind="status",status="complete",taskId=old,dock=dock()},m.protocol)
    c.handle(41,{version=1,id=41,message="late",context={taskId=old},progress={completed=999}},m.telemetryProtocol)
    eq(c.state.workers[41].taskId,current); eq(c.state.workers[41].status,"assigned")
    local ok,err=c.control("stop",nil,digging.id)
    eq(ok,false); eq(err,"unknown_job"); eq(c.state.pendingControls[41],nil)
    eq(c.state.jobs[building.id].tasks[42].status,"assigned")
end)
test("legacy controller job migrates without losing assignments or reservations",function()
    local c,m=controllerWithWorkers(); local a=assignment()
    assert(c.start(a.a,a.b,{41},a.stations))
    local old=c.state.job
    require("fleet_store").save("data/fleet-state.txt",{version=1,workers=c.state.workers,job=old,serial=4,
        locks={service={owner=41,token="old"}}})
    local restarted=require("fleet_controller").new(require("fleet_settings").defaults())
    eq(restarted.state.jobs[old.id].tasks[41].id,old.tasks[41].id)
    eq(restarted.snapshot().serviceOwner,41); eq(restarted.snapshot().workers[41].taskType,"quarry")
    restarted.tick()
    local saved=require("fleet_store").load("data/fleet-state.txt",{})
    eq(saved.version,2); eq(saved.job,nil); assert(saved.jobs[old.id])
end)
test("failed jobs reserve their area until reset while unrelated jobs continue",function()
    local c,m,digging,building,st=mixedJobs(); local id=digging.tasks[41].id
    c.handle(41,{version=1,id=41,kind="status",status="failed",taskId=id,dock=dock(),error="blocked"},m.protocol)
    local ok,err=c.start(digging.tasks[41].assignment.a,digging.tasks[41].assignment.b,{43},st)
    eq(ok,false); assert(err:find("job_area_conflict",1,true))
    c.control("reset",nil,digging.id)
    local pending=c.state.pendingControls[41]
    c.handle(41,{version=1,id=41,kind="reset_result",request=pending.request,taskId=id,ok=true},m.protocol)
    eq(digging.tasks[41].status,"cancelled"); eq(building.tasks[42].status,"assigned")
    c.handle(41,{version=1,id=41,kind="status",status="running",taskId=id,dock=dock()},m.protocol)
    eq(c.state.workers[41].status,"idle"); eq(c.state.workers[41].taskId,nil)
    assert(c.start(digging.tasks[41].assignment.a,digging.tasks[41].assignment.b,{43},st))
end)
test("fleet menu targets an entire selected job without commanding another job",function()
    local c,m,digging,building=mixedJobs()
    require("fleet_controller").new=function() return c end
    peripheral.find=function() return nil end
    local sent={}
    rednet.send=function(id,p) sent[#sent+1]={id=id,action=p.action,taskId=p.taskId}; return true end
    local choices={6,7,8,9,0}; local dialog=require("fleet_dialog")
    dialog.number=function(prompt)
        if prompt=="Volba" then assert(#choices>0); return table.remove(choices,1) end
        if prompt:find("Ovladat:",1,true) or prompt=="Vyber ulohu zo zoznamu" then return 2 end
        error("Unexpected question: "..prompt)
    end
    parallel.waitForAny=function(_,input) input() end
    assert(pcall(loadfile(ROOT.."/turtle/fleet.lua")))
    eq(#sent,4)
    for i,action in ipairs({"pause","resume","stop","reset"}) do
        eq(sent[i].id,42); eq(sent[i].action,action); eq(sent[i].taskId,building.tasks[42].id)
    end
    eq(c.state.pendingControls[41],nil); eq(c.state.pendingControls[42].action,"reset")
end)

test("idle controller avoids repeated writes and persists changed progress on its next checkpoint",function()
    local c,m=controllerWithWorkers(); c.tick()
    local writes=0; local save=require("fleet_store").save
    require("fleet_store").save=function(...) writes=writes+1; return save(...) end
    for i=1,10 do
        world().ticks=i*2
        for _,id in ipairs({41,42,43}) do
            c.handle(id,{version=1,id=id,kind="status",status="idle",dock=dock(),fuel=1000},m.protocol)
        end
        c.tick()
    end
    eq(writes,0)
    local job=assignment(); assert(c.start(job.a,job.b,{41},job.stations))
    local id=c.state.job.tasks[41].id
    c.handle(41,{version=1,id=41,kind="status",status="running",dock=dock(),taskId=id},m.protocol)
    writes=0
    c.handle(41,{version=1,id=41,message="progress",context={taskId=id},progress={completed=7}},m.telemetryProtocol)
    world().ticks=world().ticks+2; c.tick(); eq(writes,1)
    local restarted=require("fleet_controller").new(require("fleet_settings").defaults())
    eq(restarted.snapshot().summary.completed,7)
end)

test("fleet display groups mixed tasks and repaints only changed lines",function()
    local display=require("fleet_display")
    local snapshot={workers={
        [41]={status="running",taskType="quarry",packet={progress={total=50,completed=20}}},
        [42]={status="paused",taskType="floor",packet={progress={total=20,completed=5}}},
        [43]={status="assigned",taskType="ceiling",taskTotal=30},
        [44]={status="idle"}}, summary={total=100,completed=25,remaining=75}}
    local groups=display.groups(snapshot)
    eq(groups[1].title,"STAVANIE"); eq(table.concat(groups[1].ids,","),"42,43")
    eq(groups[1].completed,5); eq(groups[1].total,50)
    eq(groups[2].title,"KOPANIE"); eq(groups[2].ids[1],41); eq(groups[3].ids[1],44)
    local width,height,row,writes,clears=80,24,1,0,0
    local lines={}
    local screen={getSize=function() return width,height end,clear=function() clears=clears+1; lines={} end,
        setCursorPos=function(x,y) eq(x,1); assert(y<=height); row=y end,
        write=function(text) assert(#text<=width); lines[row]=text; writes=writes+1 end}
    display.draw(screen,snapshot,0,true)
    local initial=writes; display.draw(screen,snapshot,0,true); eq(writes,initial); eq(clears,1)
    snapshot.workers[41].packet.fuel=123
    display.draw(screen,snapshot,0,true); eq(writes,initial+1); eq(clears,1)
    snapshot.workers[41]=nil
    display.draw(screen,snapshot,0,true)
    assert(not table.concat(lines,"\n"):find("KOPANIE",1,true))
    width,height=26,20; display.draw(screen,snapshot,1,false); eq(clears,2)
    assert(table.concat(lines,"\n"):find("#42",1,true))
end)
test("controller supplies assigned task categories before progress and preserves them during services",function()
    local c,m=controllerWithWorkers()
    local st=stations(); st.materials={x=4,y=0,z=2,direction=1,side="front"}
    assert(c.start({x=8,y=-1,z=2},{x=9,y=-1,z=3},{41},st,nil,nil,{kind="floor"}))
    local snapshot=c.snapshot()
    eq(snapshot.workers[41].taskType,"floor"); eq(snapshot.workers[41].taskTotal,4)
    local id=c.state.job.tasks[41].id
    c.handle(41,{version=1,id=41,kind="status",status="running",taskId=id,dock=dock(),activity="refuel"},m.protocol)
    eq(c.snapshot().workers[41].taskType,"floor")
    eq(require("fleet_display").groups(c.snapshot())[1].title,"STAVANIE")
end)

test("fleet overview pages repeat category headings and eventually show every worker",function()
    local snapshot={workers={}}
    for id=1,20 do snapshot.workers[id]={status="running",taskType=id<=10 and "floor" or "quarry"} end
    local seen,row,lines={},1,{}
    local screen={getSize=function() return 70,16 end,clear=function() lines={} end,
        setCursorPos=function(_,y) row=y end,write=function(text) lines[row]=text end}
    for time=0,50,5 do
        world().ticks=time; require("fleet_display").draw(screen,snapshot,0,true)
        local heading=false
        for y=1,15 do
            local line=lines[y] or ""
            if line:find("STAVANIE",1,true) or line:find("KOPANIE",1,true) then heading=true end
            local id=line:match("^(%d+)%s")
            if id then assert(heading,"Page omitted group heading"); seen[tonumber(id)]=true end
        end
    end
    for id=1,20 do assert(seen[id],"Worker missing from overview: "..id) end
end)

test("fleet menu dispatches adjacent job choices and correctly maps control and exit choices",function()
    local c=require("fleet_settings").defaults(); c.stations={fuel=stations().fuel,output=stations().output,
        materials={x=4,y=0,z=2,direction=1,side="front"}}; c.defaults={fuel="fuel",output="output",materials="materials"}
    require("fleet_settings").load=function() return c end
    local kinds,actions,runs={},{},{}
    local control={settings=c,state={locks={}},available=function() return {41} end,
        start=function(_,_,_,_,_,_,options) kinds[#kinds+1]=options.kind; return true end,
        control=function(action) actions[#actions+1]=action end,save=function() end,
        snapshot=function() return {workers={},summary={completed=0,total=0,remaining=0}} end}
    require("fleet_controller").new=function() return control end
    peripheral.find=function() return nil end
    shell={run=function(name) runs[#runs+1]=name; return true end}
    local choices={1,2,3,4,5,6,7,8,9,10,11,0}
    local dialog=require("fleet_dialog")
    dialog.number=function(prompt,default)
        if prompt=="Volba" then assert(#choices>0); return table.remove(choices,1) end
        return default
    end
    dialog.yes=function(prompt) return prompt:find("Spustit",1,true)~=nil end
    local points=0
    dialog.point=function() points=points+1; return points%2==1 and {x=8,y=0,z=4} or {x=11,y=2,z=7} end
    dialog.flatPoint=function(_,y) return {x=9,y=y,z=5} end
    dialog.text=function(prompt) return prompt:find("VOLNE",1,true) and "VOLNE" or "" end
    dialog.choose=function(_,_,default) return default end
    parallel.waitForAny=function(_,input) input() end
    assert(pcall(loadfile(ROOT.."/turtle/fleet.lua")))
    eq(table.concat(kinds,","),"quarry,floor,ceiling,walls")
    eq(table.concat(actions,","),"pause,resume,stop,reset"); eq(runs[1],"fleet_setup"); eq(#choices,0)
end)

test("fleet wall closure waits for completed peers and persists across controller restarts",function()
    local c,m=controllerWithWorkers()
    local st=stations(); st.materials={x=4,y=0,z=2,direction=1,side="front"}
    assert(c.start({x=8,y=0,z=4},{x=14,y=2,z=10},{41,42,43},st,nil,nil,{kind="walls"}))
    local job=c.state.job; eq(job.total,60); eq(job.closer,43)
    local response
    rednet.send=function(_,p) if p.kind=="walls_reply" then response=p end; return true end
    local function query(id,taskId)
        c.handle(id,{version=1,id=id,kind="walls_ready",request="query",taskId=taskId or job.tasks[id].id},m.protocol)
        return response
    end
    eq(query(43).granted,false); eq(query(41).error,"invalid_wall_closer")
    for _,id in ipairs({41,42}) do
        c.handle(id,{version=1,id=id,kind="status",status="complete",taskId=job.tasks[id].id,dock=dock(),
            progress={completed=job.tasks[id].total}},m.protocol)
    end
    eq(query(43).granted,true)
    c=require("fleet_controller").new(require("fleet_settings").defaults())
    eq(query(43).granted,true); eq(query(43,"old-task").granted,false)
    c.state.jobs[job.id].tasks[42].status="failed"
    eq(query(43).granted,false)
end)

test("wall assignments require material stations and retain their exact work region",function()
    local model,task=require("fleet_model"),require("fleet_task")
    local first,last={x=8,y=0,z=4},{x=14,y=2,z=10}
    local parts,_,whole=model.splitWalls(first,last,2)
    local job={id="walls:1",jobId="walls",kind="walls",a=first,b=last,area=whole,
        stations=stations(),wallOptions=parts[1].wallOptions}
    local c,err=task.settings(job,dock()); eq(c,nil); eq(err,"station_missing:materials")
    job.stations.materials={x=4,y=0,z=2,direction=1,side="front"}
    local valid,_,box=task.settings(job,dock()); assert(valid); eq(box.volume,parts[1].total)
    job.wallOptions.segment.last=999
    c,err=task.settings(job,dock()); eq(c,nil); eq(err,"invalid_wall_segment")
end)

test("wall tasks allow an interior shaft and floor exits but reject actual wall crossings",function()
    local first,last={x=8,y=5,z=0},{x=17,y=8,z=9}
    local parts,_,whole=require("fleet_model").splitWalls(first,last,2)
    local st=stations(); st.materials={x=4,y=0,z=2,direction=1,side="front"}
    local job={id="walls:1",jobId="walls",kind="walls",a=first,b=last,area=whole,stations=st,
        wallOptions=parts[1].wallOptions,floor="upper",tunnel={x=12,z=4,
        floors={base={exit={x=14,y=0,z=4}},upper={exit={x=14,y=6,z=4}}}}}
    local task=require("fleet_task")
    local c,err,box=task.settings(job,dock()); assert(c,err)
    eq(box.interiorAccess,true); eq(job.wallOptions.interiorAccess,true)
    eq(require("wall_plan").protected(box).opening,nil)
    local stand=require("wall_access").new(box).stand(box.opening)
    eq(stand.x,box.min.x+1)
    job.tunnel.floors.upper.exit.x=17
    c,err=task.settings(job,dock()); eq(c,nil); eq(err,"floor_exit_inside_area")
    job.tunnel.floors.upper.exit.x=19
    c,err=task.settings(job,dock()); eq(c,nil); eq(err,"floor_corridor_inside_area")
    job.tunnel.floors.upper.exit.x=14; job.tunnel.z=1
    job.tunnel.floors.upper.exit.z=1; job.tunnel.floors.base.exit.z=1
    c,err=task.settings(job,dock()); eq(c,nil); eq(err,"tunnel_inside_area")
end)

test("fleet split covers reversed corners without overlapping cells", function()
    local cuboid, model = require("cuboid"), require("fleet_model")
    local a, b = { x = 11, y = 4, z = 5 }, { x = 2, y = 2, z = 2 }
    local segments = assert(model.split(a, b, 3))
    local seen, total = {}, 0
    for _, segment in ipairs(segments) do
        local box = assert(cuboid.new(segment.a, segment.b)); total = total + box.volume
        for i = 1, box.volume do
            local p = cuboid.cell(box, i, segment.a); local key = p.x .. "," .. p.y .. "," .. p.z
            assert(not seen[key]); seen[key] = true
        end
    end
    eq(total, 120); eq(segments[1].a.x, 11); eq(segments[3].b.x, 2)
    eq(segments[1].total, 48); eq(segments[2].total, 36)
end)
test("fleet uses Z strips for a long Z area and rejects excessive worker count", function()
    local model = require("fleet_model")
    local a, b = { x = 8, y = 0, z = -4 }, { x = 8, y = 0, z = 5 }
    local s = assert(model.split(a, b, 2)); eq(s[1].a.z, -4); eq(s[2].a.z, 1)
    eq(model.split(a, b, 11), nil)
end)
test("fleet totals ignore repeated traversal and clamp completed cells", function()
    local s = require("fleet_model").summary({ total = 20, tasks = {
        [41] = { total = 10, status = "complete", progress = { completed = 100, dug = 12 } },
        [42] = { total = 10, status = "running", progress = { completed = 4, dug = 4 } },
    } })
    eq(s.completed, 14); eq(s.remaining, 6); eq(s.dug, 16); eq(s.active, 1)
end)
test("progress from an older worker checkpoint cannot decrease the saved completion count", function()
    local m, t = require("fleet_model"), {total=100}
    m.updateProgress(t, {completed=50,dug=55,phase="mining"})
    m.updateProgress(t, {completed=40,dug=45,phase="failed"})
    eq(t.progress.completed,50); eq(t.progress.remaining,50); eq(t.progress.dug,55); eq(t.progress.phase,"failed")
end)
test("service reservations reject another owner and stale release tokens", function()
    local m, locks = require("fleet_model"), {}
    assert(m.acquire(locks, "service", 41, "a")); assert(m.acquire(locks, "service", 41, "a"))
    eq(m.acquire(locks, "service", 42, "b"), false)
    eq(m.release(locks, "service", 42, "a"), false)
    assert(m.release(locks, "service", 41, "a"))
    assert(m.acquire(locks, "service", 41, "new"))
    eq(m.release(locks, "service", 41, "a"), false); eq(locks.service.token, "new")
end)

test("different chest endpoints can be occupied concurrently but the same endpoint cannot", function()
    local m,locks=require("fleet_model"),{}
    assert(m.acquire(locks,"station:2,0,2",41,"fuel"))
    assert(m.acquire(locks,"station:-2,0,2",42,"output"))
    eq(m.acquire(locks,"station:2,0,2",43,"other"),false)
    local owners=m.serviceOwners(locks); eq(#owners,2); eq(owners[1],41); eq(owners[2],42)
end)

test("startup visits go chest to chest and restore normal return behaviour even after an error", function()
    env.configured(stations())
    local nav,lib=require("navigation"),require("stations")
    local p,calls=dock(),{}
    nav.getPosition=function() return p end
    nav.moveToCoord=function(x,y,z) p={x=x,y=y,z=z}; calls[#calls+1]=p; return true end
    peripheral.hasType=function() return true end
    lib.setRuntime(nil,nil,true)
    assert(lib.startup(function() assert(lib.verify("fuel")); return lib.verify("output") end))
    eq(#calls,2); eq(calls[1].x,2); eq(calls[2].x,-2)
    eq(p.x,-2)
    eq(pcall(function() lib.startup(function() error("test failure") end) end),false)
    assert(lib.verify("fuel")); eq(#calls,4); eq(p.x,-2)
end)
test("durable state survives interrupted rename without forgetting reservations", function()
    local W, store = world(), require("fleet_store")
    store.save("data/fleet-state.txt", { locks = { service = { owner = 41, token = "a" } } })
    fs.move("data/fleet-state.txt", "data/fleet-state.txt.bak")
    W.files["data/fleet-state.txt.tmp"] = "broken"
    eq(store.load("data/fleet-state.txt", {}).locks.service.owner, 41)
end)
test("CC serializer rejects repeated references but shared config values save safely", function()
    local c=env.configured()
    c.home=c.start
    local shared={x=2,y=0,z=2,direction=1,side="front"}
    c.stations.fuel,c.stations.output=shared,shared
    local rawOK,rawErr=pcall(textutils.serialize,c)
    eq(rawOK,false); assert(tostring(rawErr):find("repeated entries",1,true))
    assert(require("config").save(c))
    local saved=assert(require("config").load())
    eq(saved.start.x,saved.home.x); assert(saved.start~=saved.home)
    eq(saved.stations.fuel.x,2); assert(saved.stations.fuel~=saved.stations.output)
end)
test("fleet persistence copies shared progress without changing runtime references", function()
    local store=require("fleet_store")
    local progress={completed=5,total=10}
    local state={task={progress=progress},worker={progress=progress}}
    store.save("data/fleet-state.txt",state)
    local saved=store.load("data/fleet-state.txt")
    eq(saved.task.progress.completed,5); eq(saved.worker.progress.completed,5)
    assert(saved.task.progress~=saved.worker.progress)
    eq(state.task.progress,state.worker.progress)
    local copy=store.copy(state)
    copy.task.progress.completed=9
    eq(copy.worker.progress.completed,5); eq(progress.completed,5)
end)
test("cyclic records are rejected before touching live files or staging", function()
    local store,W=require("fleet_store"),world()
    local path="data/fleet-state.txt"
    store.save(path,{serial=7})
    local original=W.files[path]
    W.files[path..".tmp"]="existing staging"
    local cycle={}; cycle.self=cycle
    local ok,err=pcall(store.save,path,cycle)
    eq(ok,false); assert(tostring(err):find("cyclic",1,true))
    eq(W.files[path],original); eq(W.files[path..".tmp"],"existing staging")
end)
test("fresh workers start without setup under strict CC serialization", function()
    local W=world(); local started=0
    parallel.waitForAny=function() started=started+1 end
    for index=1,3 do
        W.files={}; W.x=index*4
        loadfile(ROOT.."/turtle/worker.lua")("16")
        local c=assert(require("config").load())
        eq(c.start.x,index*4); eq(c.home.x,index*4); assert(c.start~=c.home)
        local state=require("fleet_store").load("data/worker-state.txt")
        eq(state.controller,16); eq(state.status,"idle"); eq(state.dock.x,index*4)
    end
    eq(started,3)
end)
test("named station settings preserve defaults and reject unknown references", function()
    local s = require("fleet_settings")
    local c = s.defaults(); c.stations = { Coal = stations().fuel }; c.defaults.fuel = "Coal"; c.tunnel = tunnel()
    assert(s.save(c)); eq(s.load().defaults.fuel, "Coal")
    c.defaults.output = "missing"; eq(s.save(c), false)
end)
local function setupAnswers(answers)
    local originalRead,originalWrite=read,write
    read=function() assert(#answers>0,"Unexpected setup question"); return table.remove(answers,1) end
    write=function() end
    local ok,err=pcall(loadfile(ROOT.."/turtle/fleet_setup.lua"))
    read,write=originalRead,originalWrite
    assert(ok,err); eq(#answers,0)
end
test("floor setup edits only floors without reentering the shaft coordinates", function()
    local settings=require("fleet_settings")
    local c=settings.defaults()
    c.tunnel={x=0,z=0,floors={base={exit={x=2,y=0,z=0}}}}
    assert(settings.save(c))
    setupAnswers({"4",
        "1","upper","2","4","0",
        "2","upper","first",
        "3","first","-2","","",
        "1","temp","0","8","2",
        "4","temp","a",
        "0","0"})
    local saved=settings.load()
    eq(saved.tunnel.x,0); eq(saved.tunnel.z,0)
    eq(saved.tunnel.floors.first.exit.x,-2); eq(saved.tunnel.floors.first.exit.y,4); eq(saved.tunnel.floors.first.exit.z,0)
    eq(saved.tunnel.floors.upper,nil); eq(saved.tunnel.floors.temp,nil)
    eq(saved.tunnel.floors.base.exit.x,2)
end)
test("new shaft and floors can be configured separately and saved together", function()
    setupAnswers({"3","","100","200","4","1","base","102","64","200","0","0"})
    local saved=require("fleet_settings").load()
    eq(saved.tunnel.x,100); eq(saved.tunnel.z,200); eq(saved.tunnel.floors.base.exit.y,64)
end)
test("floor editing rejects collisions and invalid exits without losing existing floors", function()
    local floors,t=require("fleet_floors"),tunnel()
    local ok,err=floors.rename(t,"upper","base")
    eq(ok,false); eq(err,"floor_name_exists"); eq(t.floors.upper.exit.y,4)
    ok,err=floors.setExit(t,"upper",{x=3,y=4,z=3})
    eq(ok,false); eq(err,"exit_must_align_with_shaft"); eq(t.floors.upper.exit.x,2)
    ok,err=floors.setExit(t,"upper",{x=2,y=0,z=0})
    eq(ok,false); eq(err,"duplicate_floor_height"); eq(t.floors.upper.exit.y,4)
    assert(floors.remove(t,"upper"))
    ok,err=floors.remove(t,"base")
    eq(ok,false); eq(err,"last_floor_required"); assert(require("transit").validate(t))
    eq(t.x,0); eq(t.z,0)
end)
test("tunnel exits must align with the centre and have distinct heights", function()
    local t, c = require("transit"), tunnel()
    assert(t.validate(c)); c.floors.upper.exit.z = 3; eq(t.validate(c), false)
    c = tunnel(); c.floors.upper.exit.y = 0; eq(t.validate(c), false)
end)
test("transit plans use the defined exits and central vertical column", function()
    local transit = require("transit")
    assert(transit.configure(tunnel(), assert(require("cuboid").new(assignment().a, assignment().b)), "upper"))
    local legs = transit.plan({ x = 4, y = 0, z = 0 }, { x = 8, y = 3, z = 2 })
    eq(#legs, 4); eq(legs[1].point.x, 2); eq(legs[2].point.x, 0); eq(legs[3].point.y, 4)
    assert(legs[3].straight); eq(legs[4].point.x, 2)
    eq(#transit.plan({ x = 8, y = 3, z = 2 }, { x = 9, y = 2, z = 3 }), 0)
    assert(transit.estimate({ x = 4, y = 0, z = 0 }, { x = 8, y = 4, z = 2 }) > 10)
end)
test("mining single steps never route through the service shaft", function()
    local transit = require("transit")
    assert(transit.configure(tunnel(), assert(require("cuboid").new(assignment().a, assignment().b)), "upper"))
    local calls = 0
    assert(transit.move({ x = 8, y = 3, z = 2 }, { maxMoves = 1 }, function() calls = calls + 1; return true end,
        function() error("unexpected lock") end, function() error("unexpected release") end,
        function() return { x = 8, y = 4, z = 2 } end))
    eq(calls, 1)
end)
test("short tunnel junction legs use tracked steps and long journeys retain GPS boundaries",function()
    local transit=require("transit"); assert(transit.configure(tunnel(),nil,"upper"))
    local p={x=4,y=0,z=0}; local short,long=0,0
    local ok,err=transit.move({x=4,y=4,z=0},{},function(x,y,z,o)
        local distance=math.abs(x-p.x)+math.abs(y-p.y)+math.abs(z-p.z)
        if distance<=1 then eq(o.positionVerified,true); eq(o.maxMoves,1); short=short+1
        else eq(o.positionVerified,nil); long=long+1 end
        p={x=x,y=y,z=z}; return true
    end,function() return true end,function() end,function() return p end)
    assert(ok,err); assert(short>=4); assert(long>=3)
end)
test("failed shaft travel retains the reservation", function()
    local transit = require("transit"); assert(transit.configure(tunnel(), nil, "upper"))
    local released = false
    local ok, err = transit.move({ x = 4, y = 4, z = 0 }, {}, function() return false, "blocked" end,
        function() return true end, function() released = true end, function() return { x = 4, y = 0, z = 0 } end)
    eq(ok, false); eq(err, "transit:blocked"); eq(released, false)
end)
test("fleet task validation protects docks, station blocks and shaft infrastructure", function()
    local lib, t = require("fleet_task"), assignment()
    assert(lib.settings(t, dock()))
    t.stations.fuel.x, t.stations.fuel.y, t.stations.fuel.z = 8, 4, 2
    eq(lib.settings(t, dock()), nil)
    t = assignment(); t.tunnel, t.floor = tunnel(), "upper"; assert(lib.settings(t, dock()))
    t.a, t.b = { x = -1, y = 0, z = -1 }, { x = 1, y = 4, z = 1 }
    eq(lib.settings(t, { x = 4, y = 0, z = 0, direction = 0 }), nil)
end)
test("controller dispatches only the selected available workers", function()
    local c = controllerWithWorkers()
    local t = assignment()
    assert(c.start(t.a, t.b, { 42, 43 }, t.stations))
    eq(c.state.job.tasks[41], nil); eq(c.state.job.total, 48)
    eq(c.state.job.tasks[42].total + c.state.job.tasks[43].total, 48)
    eq(c.state.workers[41].status, "idle"); eq(c.state.workers[42].status, "assigned")
    eq(c.state.job.tasks[42].assignment.lane,1); eq(c.state.job.tasks[43].assignment.lane,2)
    eq(c.state.job.tasks[42].assignment.startDelay,0); eq(c.state.job.tasks[43].assignment.startDelay,5)
    eq(c.start(t.a, t.b, { 41 }, t.stations), false)
end)
test("controller also protects the dock of an unselected turtle", function()
    local c = controllerWithWorkers()
    c.state.workers[43].dock = {x=8,y=4,z=2,direction=0}
    local t = assignment()
    local ok, err = c.start(t.a,t.b,{41},t.stations)
    eq(ok,false); eq(err,"dock_inside_area:43")
end)
test("work area cannot remove a doorway corridor between the shaft and its exit", function()
    local t = assignment(); t.tunnel=tunnel(); t.floor="upper"
    t.tunnel.floors.upper.exit.x=6
    t.a,t.b={x=4,y=4,z=0},{x=5,y=4,z=0}
    local c,err=require("fleet_task").settings(t,dock())
    eq(c,nil); eq(err,"floor_corridor_inside_area")
end)
test("controller persists progress and does not overwrite it with an older task", function()
    local c, m = controllerWithWorkers(); local t = assignment()
    assert(c.start(t.a, t.b, { 41 }, t.stations))
    local id = c.state.job.tasks[41].id
    c.handle(41, { version = 1, id = 41, kind = "status", status = "running", dock = dock(), taskId = id,
        progress = { completed = 12, total = 48, remaining = 36, dug = 12 } }, m.protocol)
    c.handle(41, { version = 1, id = 41, message = "old", context = { taskId = "old" },
        progress = { completed = 48 } }, m.telemetryProtocol)
    eq(c.snapshot().summary.completed, 12)
    c.save()
    local restarted = require("fleet_controller").new(require("fleet_settings").defaults())
    eq(#restarted.available(), 0); eq(restarted.snapshot().summary.completed, 12)
    eq(restarted.state.job.tasks[41].status, "running")
end)
test("coordinator restart retains the service owner even after a long offline period", function()
    local c, m = controllerWithWorkers(); local t = assignment()
    assert(c.start(t.a, t.b, { 41 }, t.stations))
    local id = c.state.job.tasks[41].id
    c.handle(41, { version = 1, id = 41, kind = "lock", request = "token", taskId = id, resource = "service" }, m.protocol)
    world().ticks = 100000
    local restarted = require("fleet_controller").new(require("fleet_settings").defaults())
    eq(restarted.snapshot().serviceOwner, 41)
    restarted.tick(); eq(restarted.snapshot().serviceOwner, 41)
end)
test("worker pairing ignores other controllers and repeated assignments never restart work", function()
    env.configured()
    local client = require("fleet_client").new(99, dock()); local t = assignment()
    client.handle(98, { version = 1, kind = "assign", task = t }); eq(client.queued, nil)
    client.handle(99, { version = 1, kind = "assign", task = t }); eq(client.queued, true)
    client.queued = false
    client.handle(99, { version = 1, kind = "assign", task = t }); eq(client.queued, false)
    client.state.status = "running"; client.save()
    local restarted = require("fleet_client").new(99, dock())
    eq(restarted.state.status, "recovery"); eq(restarted.queued, nil)
    restarted.handle(99, { version = 1, kind = "control", action = "stop", taskId = t.id })
    eq(restarted.queued, true); eq(restarted.recovery, true)
end)
test("resume requeues failed or recovery segments without replacing their saved task", function()
    env.configured()
    for _,status in ipairs({"failed","recovery"}) do
        local c=require("fleet_client").new(99,dock())
        c.state.status,c.state.task=status,assignment()
        c.state.progress={visited=12,completed=12,total=48,remaining=36,dug=12}
        c.paused,c.cancel=true,true
        local command={version=1,kind="control",action="resume",request="retry:"..status,order=10,taskId=c.state.task.id}
        c.handle(99,command)
        eq(c.state.status,"assigned"); eq(c.queued,true); eq(c.retry,true); eq(c.recovery,false)
        eq(c.paused,false); eq(c.cancel,false); eq(c.state.progress.visited,12)
        c.queued=false; c.handle(99,command); eq(c.queued,false)
        local saved=require("fleet_store").load("data/worker-state.txt")
        eq(saved.task.id,"job:1"); eq(saved.progress.visited,12)
        -- Reset the control sequence for the independent second scenario.
        c.state.lastControl,c.state.controlSeen=nil,{}; c.save()
    end
end)
test("resume cannot restart a completed segment", function()
    env.configured(); local c=require("fleet_client").new(99,dock())
    c.state.status,c.state.task="complete",assignment()
    c.handle(99,{version=1,kind="control",action="resume",taskId=c.state.task.id})
    eq(c.state.status,"complete"); eq(c.queued,nil)
end)
test("worker rejects a second assignment while working on its first", function()
    env.configured()
    local c = require("fleet_client").new(99, dock())
    c.handle(99, { version = 1, kind = "assign", task = assignment("one") })
    c.handle(99, { version = 1, kind = "assign", task = assignment("two") })
    eq(c.state.task.id, "one"); eq(world().packets[#world().packets].kind, "reject")
end)
test("worker heartbeat saves a progress checkpoint for recovery after a reboot", function()
    env.configured(); local c = require("fleet_client").new(99,dock())
    c.state.status, c.state.task = "running", assignment()
    require("telemetry").setProgress({completed=12,total=48,remaining=36,dug=13,phase="mining"})
    world().ticks = 3; c.status()
    local s = require("fleet_store").load("data/worker-state.txt")
    eq(s.progress.completed,12); eq(s.progress.dug,13)
end)
test("worker reservations nest and release using the granted token", function()
    env.configured(); local c = require("fleet_client").new(99, dock())
    local requests, releases = {}, {}
    rednet.send = function(_, p)
        if p.kind == "lock" then
            requests[#requests+1] = p.request
            c.handle(99, { version = 1, kind = "lock_reply", request = p.request, granted = true })
        elseif p.kind == "release" then releases[#releases+1] = p.token end
    end
    assert(c.acquire("service")); assert(c.acquire("service")); eq(#requests, 1)
    c.release("service"); eq(#releases, 0)
    c.release("service"); eq(releases[1], requests[1])
    eq(c.state.pendingRelease.service, requests[1])
    c.handle(99, { version = 1, kind = "release_reply", resource = "service", token = requests[1] })
    assert(c.acquire("service")); assert(requests[2] ~= requests[1])
end)
test("an occupied service keeps waiting beyond five minutes while the PC responds", function()
    env.configured(); local c=require("fleet_client").new(99,dock())
    rednet.send=function(_,p)
        if p.kind=="lock" then c.handle(99,{version=1,kind="lock_reply",request=p.request,
            granted=world().ticks>320,error=world().ticks<=320 and "occupied" or nil}) end
    end
    sleep=function() world().ticks=world().ticks+10 end
    assert(c.acquire("service")); assert(world().ticks>300)
end)
test("missing controller is a recoverable communication error rather than infinite waiting", function()
    env.configured(); local c=require("fleet_client").new(99,dock())
    rednet.send=function() return true end
    sleep=function() world().ticks=world().ticks+100 end
    local ok,err=c.acquire("service")
    eq(ok,false); eq(err,"controller_unreachable:service")
end)
test("reset in dock returns idle and duplicate commands resend their result", function()
    env.configured(); env.navReady(); local c=require("fleet_client").new(99,dock())
    c.state.status,c.state.task="failed",assignment()
    c.state.progress={visited=5,completed=5,total=48,remaining=43,dug=5}
    c.state.lockTokens.service="mine"
    local command={version=1,kind="control",action="reset",request="reset:1",order=1,taskId=c.state.task.id}
    c.handle(99,command); eq(c.state.status,"idle"); eq(c.state.task,nil); eq(c.state.progress,nil)
    eq(c.state.pendingRelease.service,"mine")
    local before=#world().packets; c.handle(99,command)
    eq(world().packets[before+1].kind,"reset_result"); eq(world().packets[before+2].kind,"control_ack")
    local saved=require("fleet_store").load("data/worker-state.txt"); eq(saved.status,"idle"); eq(saved.dock.x,0)
end)
test("reset refuses a running worker or a worker away from its dock", function()
    env.configured(); env.navReady(); local c=require("fleet_client").new(99,dock())
    c.state.status="running"; local ok,err=c.reset(); eq(ok,false); eq(err,"reset_requires_stop")
    c.state.status="failed"; world().x=1; env.navReady()
    ok,err=c.reset(); eq(ok,false); eq(err,"reset_requires_dock"); eq(c.state.status,"failed")
end)
test("controller only completes reset after the result, then accepts a new job", function()
    local c,m=controllerWithWorkers(); local t=assignment()
    assert(c.start(t.a,t.b,{41},t.stations))
    local oldId=c.state.job.tasks[41].id
    c.control("reset",41); local request=c.state.pendingControls[41].request
    c.handle(41,{version=1,id=41,kind="control_ack",request=request},m.protocol)
    assert(c.state.pendingControls[41])
    c.handle(41,{version=1,id=41,kind="reset_result",request=request,taskId=oldId,ok=true},m.protocol)
    eq(c.state.job.tasks[41].status,"cancelled"); eq(c.state.workers[41].status,"idle")
    eq(c.snapshot().summary.active,0); eq(c.snapshot().summary.failed,0)
    assert(c.start(t.a,t.b,{41},t.stations))
end)
test("stop retries are acknowledged without cancelling the return trip a second time", function()
    env.configured(); local c = require("fleet_client").new(99, dock())
    c.state.status, c.state.task = "running", assignment()
    local command = { version = 1, kind = "control", action = "stop", request = "stop:1", taskId = c.state.task.id }
    c.handle(99, command); eq(c.checkpoint(), false)
    c.handle(99, command); assert(c.checkpoint())
    eq(world().packets[#world().packets].kind, "control_ack")
end)
test("controller repeats control commands until their matching acknowledgement", function()
    local c, m = controllerWithWorkers()
    c.control("pause", 41)
    local request = c.state.pendingControls[41].request
    c.tick(); assert(c.state.pendingControls[41])
    c.handle(41, { version=1,id=41,kind="control_ack",request="old" }, m.protocol)
    assert(c.state.pendingControls[41])
    c.handle(41, { version=1,id=41,kind="control_ack",request=request }, m.protocol)
    eq(c.state.pendingControls[41], nil)
end)
test("delayed older pause cannot override a newer resume", function()
    env.configured(); local c = require("fleet_client").new(99,dock())
    c.state.status,c.state.task="running",assignment()
    c.handle(99,{version=1,kind="control",action="resume",request="new",order=2,taskId=c.state.task.id})
    c.handle(99,{version=1,kind="control",action="pause",request="old",order=1,taskId=c.state.task.id})
    eq(c.paused,false); eq(c.state.lastControl,2)
end)
test("pause waits without moving and stop is consumed before the return journey", function()
    env.configured(); local c = require("fleet_client").new(99, dock())
    c.state.status = "running"; c.paused = true
    sleep = function() c.paused = false end
    assert(c.checkpoint()); eq(world().moves, 0)
    c.cancel = true; eq(c.checkpoint(), false); assert(c.checkpoint())
end)
test("navigation and digging honour a worker stop before the next destructive action", function()
    env.configured(stations()); local nav = env.navReady()
    nav.setRuntime(nil, function() return false, "job_cancelled" end)
    world().blocks["1,0,0"] = true
    local box = assert(require("cuboid").new({ x = 1, y = 0, z = 0 }, { x = 1, y = 0, z = 0 }))
    local ok, err = require("mining").stepTo(box.min, box, { dug = 0 })
    eq(ok, false); eq(err, "job_cancelled"); eq(#world().digs, 0); eq(world().moves, 0)
end)
test("shared-station parking holds the reservation until departing the station", function()
    local depth, p = 0, dock()
    local client = { acquire = function() depth = depth + 1; return true end,
        release = function() depth = depth - 1 end }
    assert(require("transit").configure(nil))
    local move = require("fleet_motion").new(client, stations(), function() return p end)
    local function raw(x,y,z) p = { x=x,y=y,z=z }; return true end
    assert(move(stations().fuel, {}, raw)); eq(depth, 1)
    assert(move(stations().fuel, {}, raw)); eq(depth, 1)
    assert(move(dock(), {}, raw)); eq(depth, 0)
end)

test("chest departure probes another cell and releases the old endpoint before acquiring the next", function()
    assert(require("transit").configure(nil))
    local p,held,attempts=dock(),nil,0
    local client={acquire=function(r) eq(held,nil); held=r; return true end,
        release=function(r) eq(held,r); held=nil end}
    local move=require("fleet_motion").new(client,stations(),function() return p end,dock())
    local function raw(x,y,z,o)
        if o.tryOnce then
            eq(o.maxMoves,1); eq(o.waitForTurtles,false); eq(o.positionVerified,true)
            attempts=attempts+1; if attempts==1 then return false,"temporary_obstacle" end
        end
        p={x=x,y=y,z=z}; return true
    end
    assert(move(stations().fuel,{},raw))
    assert(move(stations().output,{},raw)); eq(attempts,2); eq(held,"station:-2,0,2")
end)
test("shaft travel holds lane reservations without locking the service floor", function()
    local model, transit = require("fleet_model"), require("transit")
    assert(transit.configure(tunnel(), nil, "upper"))
    local locks, depths, p = {}, {}, dock()
    local client = {
        acquire = function(resource)
            assert(model.acquire(locks, resource, 41, resource))
            depths[resource] = (depths[resource] or 0) + 1; return true
        end,
        release = function(resource)
            depths[resource] = depths[resource] - 1; assert(depths[resource] >= 0)
            if depths[resource] == 0 then assert(model.release(locks, resource, 41, resource)) end
        end,
    }
    local move = require("fleet_motion").new(client, stations(), function() return p end, dock())
    local overlapped = false
    local function raw(x,y,z)
        if y == 4 and x == 0 then
            assert(not locks.service); eq(model.tunnelOwners(locks)[1], 41)
            assert(model.acquire(locks, "service", 42, "next"))
            eq(model.acquire(locks, "tunnel", 42, "next"), false)
            assert(model.release(locks, "service", 42, "next")); overlapped = true
        end
        p = {x=x,y=y,z=z}; return true
    end
    assert(move({x=8,y=4,z=0}, {}, raw)); assert(overlapped); eq(next(locks), nil)
    assert(move(dock(), {}, function(x,y,z)
        eq(locks.service, nil)
        p={x=x,y=y,z=z}; return true
    end)); eq(next(locks), nil)
end)
test("failed outbound shaft retains tunnel reservation after service handoff", function()
    local transit = require("transit"); assert(transit.configure(tunnel(), nil, "upper"))
    local depth, p = {}, dock()
    local client = { acquire=function(r) depth[r]=(depth[r] or 0)+1; return true end,
        release=function(r) depth[r]=depth[r]-1 end }
    local move=require("fleet_motion").new(client,stations(),function() return p end,dock())
    local ok,err=move({x=8,y=4,z=0},{},function(x,y,z)
        if y==4 then return false,"blocked" end
        p={x=x,y=y,z=z}; return true
    end)
    eq(ok,false); eq(err,"transit:blocked"); eq(depth.service,nil)
    local lane=require("tunnel_traffic").lane(true); eq(depth[lane],1)
end)
test("tunnel and service locks are independent and both survive coordinator restart", function()
    local c,m=controllerWithWorkers()
    assert(c.start({x=8,y=4,z=2},{x=9,y=4,z=2},{41,42},stations()))
    for id,r in pairs({[41]="tunnel",[42]="service"}) do
        c.handle(id,{version=1,id=id,kind="lock",taskId=c.state.job.tasks[id].id,resource=r,request=r},m.protocol)
    end
    local restarted=require("fleet_controller").new(require("fleet_settings").defaults())
    eq(restarted.snapshot().serviceOwner,42); eq(restarted.snapshot().tunnelOwner,41)
    restarted.tick(); eq(restarted.snapshot().tunnelOwner,41)
end)
test("quarry uses the service shaft through solid floor slabs and returns to its own dock", function()
    local W = world(); W.x = 4
    local c = env.configured({ fuel = { x = 3, y = 0, z = 3, direction = 1, side = "front" },
        output = { x = 3, y = 0, z = -3, direction = 1, side = "front" } })
    c.start, c.home = { x = 4, y = 0, z = 0, direction = 0 }, { x = 4, y = 0, z = 0, direction = 0 }
    assert(require("config").save(c))
    W.chests["4,0,3"] = { items = { { name = "minecraft:coal", count = 64 } } }
    W.chests["4,0,-3"] = { items = {} }
    for x = -20, 20 do for y = 1, 3 do for z = -20, 20 do
        if math.abs(x) > 1 or math.abs(z) > 1 then W.blocks[x .. "," .. y .. "," .. z] = true end
    end end end
    W.blocks["5,4,0"], W.blocks["6,4,0"] = true, true
    local nav = env.navReady(); local depth, vertical = 0, 0
    local client = { acquire = function() depth = depth + 1; return true end,
        release = function() depth = depth - 1; assert(depth >= 0) end }
    local box = assert(require("cuboid").new({ x=5,y=4,z=0 }, { x=6,y=4,z=0 }))
    assert(require("transit").configure(tunnel(), box, "upper"))
    nav.setRuntime(require("fleet_motion").new(client, c.stations, nav.getPosition), nil, require("transit").estimate)
    require("stations").setRuntime(client.acquire, client.release)
    for _, side in ipairs({ "up", "down" }) do
        local original = turtle[side]
        turtle[side] = function()
            local targetY = W.y + (side == "up" and 1 or -1)
            if math.min(W.y, targetY) < 4 and math.max(W.y, targetY) > 0 then
                assert(math.abs(W.x) <= 1 and math.abs(W.z) <= 1, "Floor slabs may only be crossed through the 3x3 shaft")
            end
            vertical = vertical + 1; return original()
        end
    end
    local ok, err, progress = require("mining").run(box.min, box.max)
    assert(ok, err); eq(progress.completed, 2); eq(#W.digs, 2)
    eq(W.x, 4); eq(W.y, 0); eq(W.z, 0); assert(depth >= 0); assert(vertical >= 8)
end)
test("pocket receiver switches from fleet overview to an individual turtle", function()
    local lines = {}
    term = { current = function() return {
        clear = function() lines = {} end, getSize = function() return 26, 20 end,
        setCursorPos = function(x,y) assert(x==1 and y<=20) end,
        write = function(text) assert(#text<=26); lines[#lines+1] = text end,
    } end }
    peripheral.find = function() return nil end
    keys = { right = 205, left = 203, tab = 15, zero = 11, numPad0 = 82 }
    local first = true
    rednet.receive = function()
        if not first then coroutine.yield(); return end
        first = false
        return 99, { version=1, id=99, kind="fleet_snapshot", summary={total=100,completed=40,remaining=60,active=2},
            workers={ [41]={status="running",packet={fuel=1234,inventory={freeSlots=7},progress={total=50,completed=20,remaining=30,dug=20}}},
                [42]={status="running",packet={fuel=555,inventory={freeSlots=4}}} } }, require("fleet_model").viewProtocol
    end
    local events = 0
    os.pullEvent = function() events = events + 1; if events==1 then return "key",keys.right end; error("end key simulation") end
    parallel.waitForAny = function(receive, input)
        local co = coroutine.create(receive); assert(coroutine.resume(co))
        assert(table.concat(lines):find("Hotove: 40/100",1,true)); input()
    end
    local ok, err = pcall(loadfile(ROOT .. "/turtle/receiver.lua"), "fleet", "99")
    eq(ok,false); assert(tostring(err):find("end key simulation",1,true))
    local text = table.concat(lines)
    assert(text:find("#41",1,true)); assert(text:find("Palivo: 1234",1,true)); assert(text:find("Zostava: 30",1,true))
end)

local function runWorkerProgram(resuming)
    local W = world()
    local c=env.configured(stations())
    W.chests["3,0,2"] = { items = { { name="minecraft:coal",count=64 } } }
    W.chests["-3,0,2"] = { items = {} }
    W.blocks["8,0,0"], W.blocks["9,0,0"] = true, true
    local t = assignment(); t.a, t.b = {x=8,y=0,z=0}, {x=9,y=0,z=0}
    local messages = { { version=1,kind="assign",task=t } }
    if resuming then
        W.blocks["8,0,0"]=nil
        require("fleet_store").save("data/worker-state.txt",{version=1,controller=99,dock=dock(),status="recovery",
            task=t,seen={[t.id]=true},previous=c,progress={visited=1,completed=1,total=2,remaining=1,dug=1,phase="failed"}})
        messages={{version=1,kind="control",action="resume",request="retry",order=1,taskId=t.id}}
    end
    local complete = false
    rednet.receive = function()
        coroutine.yield()
        local p = table.remove(messages,1)
        if p then return 99,p end
    end
    rednet.send = function(_, p)
        W.packets[#W.packets+1] = p
        if p.kind == "lock" then messages[#messages+1] = {version=1,kind="lock_reply",request=p.request,granted=true}
        elseif p.kind == "release" then messages[#messages+1] = {version=1,kind="release_reply",resource=p.resource,token=p.token}
        elseif p.kind == "status" and p.status == "complete" then complete = true
        elseif p.kind == "status" and p.status == "recovery" then error("unexpected recovery: " .. tostring(p.error)) end
        return true
    end
    sleep = function(seconds) W.ticks = W.ticks + seconds; coroutine.yield() end
    parallel.waitForAny = function(...)
        local threads = {}; for _, fn in ipairs({...}) do threads[#threads+1] = coroutine.create(fn) end
        for _ = 1, 20000 do
            for _, thread in ipairs(threads) do
                local ok, err = coroutine.resume(thread); assert(ok, err)
                if complete then return end
            end
        end
        error("worker job did not finish")
    end
    loadfile(ROOT .. "/turtle/worker.lua")("99", "0")
    assert(complete); eq(#W.digs,resuming and 1 or 2); eq(W.x,0); eq(W.y,0); eq(W.z,0)
    local state = require("fleet_store").load("data/worker-state.txt")
    eq(state.status,"complete"); eq(state.progress.completed,2); eq(state.progress.dug,2)
    eq(require("config").load().stations.output.x,-2)
end
test("worker program completes an assigned job with its real background RPC listener", function() runWorkerProgram(false) end)
test("worker program retries a persisted segment through the existing resume command", function() runWorkerProgram(true) end)
