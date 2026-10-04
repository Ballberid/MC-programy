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
    setupAnswers({"5",
        "1","upper","2","4","0",
        "2","upper","first",
        "3","first","-2","","",
        "1","temp","0","8","2",
        "4","temp","a",
        "0","4"})
    local saved=settings.load()
    eq(saved.tunnel.x,0); eq(saved.tunnel.z,0)
    eq(saved.tunnel.floors.first.exit.x,-2); eq(saved.tunnel.floors.first.exit.y,4); eq(saved.tunnel.floors.first.exit.z,0)
    eq(saved.tunnel.floors.upper,nil); eq(saved.tunnel.floors.temp,nil)
    eq(saved.tunnel.floors.base.exit.x,2)
end)
test("new shaft and floors can be configured separately and saved together", function()
    setupAnswers({"3","","100","200","5","1","base","102","64","200","0","4"})
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
            eq(o.maxMoves,1); eq(o.waitForTurtles,false)
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
