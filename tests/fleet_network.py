"""Exercise two isolated CC workers against one controller over a queued radio."""
from collections import deque


def run(root, runtime_type, kind="quarry", shaft=False, worker_count=2):
    prefix = (root / "tests" / "turtle_spec.lua").read_text(encoding="utf-8")
    prefix = prefix[:prefix.index('test("targeted refuel')]
    workers=tuple(range(41,41+worker_count))
    queues = {identity:deque() for identity in (99,*workers)}
    machines = {}
    clock = [0.0]

    def send(source, recipient, message, protocol):
        destinations = [recipient] if recipient is not None else [i for i in queues if i != source]
        for target in destinations:
            if target in queues:
                queues[target].append((source, message, protocol))

    def receive(machine, protocol=None):
        while queues[machine]:
            packet = queues[machine].popleft()
            if protocol is None or packet[2] == protocol:
                return packet
        return None, None, None

    def occupied(machine, x, y, z):
        for identity, (_, env) in machines.items():
            if identity == machine or identity == 99:
                continue
            world = env["world"]()
            if (world["x"], world["y"], world["z"]) == (x, y, z):
                return True
        return False

    def cleared(machine, x, y, z):
        key = f"{x},{y},{z}"
        for identity, (_, env) in machines.items():
            if identity != 99 and identity != machine:
                env["world"]()["blocks"][key] = None

    def placed(machine, x, y, z, name):
        key = f"{x},{y},{z}"
        for identity, (_, env) in machines.items():
            if identity != 99 and identity != machine:
                world = env["world"]()
                world["blocks"][key], world["blockNames"][key] = True, name

    for identity in queues:
        lua = runtime_type(unpack_returned_tuples=True)
        lua.globals().ROOT = root.as_posix()
        env = lua.execute(prefix + '\nreset(); return {world=function() return W end, configured=configured, adjacent=adjacent}')
        lua.globals().TEST_ENV = env
        lua.globals().MACHINE_ID = identity
        lua.globals().PY_SEND = send
        lua.globals().PY_RECEIVE = receive
        lua.globals().PY_CLOCK = lambda: clock[0]
        lua.globals().PY_OCCUPIED = occupied
        lua.globals().PY_CLEARED = cleared
        lua.globals().PY_PLACED = placed
        lua.globals().JOB_KIND = kind
        lua.globals().USE_SHAFT = shaft
        lua.execute('''
            os.getComputerID = function() return MACHINE_ID end
            os.clock = function() return PY_CLOCK() end
            rednet.send = function(id,p,protocol) PY_SEND(MACHINE_ID,id,textutils.serialize(p),protocol); return true end
            rednet.broadcast = function(p,protocol) PY_SEND(MACHINE_ID,nil,textutils.serialize(p),protocol) end
            rednet.receive = function(protocol)
                local sender,text,receivedProtocol = PY_RECEIVE(MACHINE_ID,protocol)
                if text then return sender,textutils.unserialize(text),receivedProtocol end
                coroutine.yield(); return nil
            end
            sleep = function() coroutine.yield() end
        ''')
        machines[identity] = lua, env

    main = machines[99][0]
    main.execute('CONTROL=require("fleet_controller").new(require("fleet_settings").defaults())')
    for identity in workers:
        lua = machines[identity][0]
        lua.execute('''
            local W=TEST_ENV.world()
            W.x = USE_SHAFT and 4 or 0
            W.z = MACHINE_ID==41 and 0 or -2*(MACHINE_ID-41)
            local c=TEST_ENV.configured({fuel={x=2,y=0,z=2,direction=1,side="front"},
                output={x=-2,y=0,z=2,direction=3,side="front"},
                materials={x=2,y=0,z=-2,direction=1,side="front"}})
            c.start={x=W.x,y=0,z=W.z,direction=0}; c.home=c.start
            assert(require("config").save(c))
            W.chests["3,0,2"]={items={{name="minecraft:coal",count=64}}}
            W.chests["-3,0,2"]={items={}}
            W.chests["3,0,-2"]={items={{name="minecraft:stone",count=640}}}
            if JOB_KIND=="quarry" then
                local bottom,top=USE_SHAFT and 21 or -19,USE_SHAFT and 40 or 0
                for x=8,11 do for y=bottom,top do for z=0,3 do W.blocks[x..","..y..","..z]=true end end end
                if USE_SHAFT then
                    for x=-20,30 do for z=-20,20 do
                        if math.abs(x)>1 or math.abs(z)>1 then W.blocks[x..",20,"..z]=true end
                    end end
                end
            else W.fuel,W.limit=20000,40000 end
            local originalPlace=turtle.placeDown
            turtle.placeDown=function()
                local p=TEST_ENV.adjacent("down")
                if PY_OCCUPIED(MACHINE_ID,p.x,p.y,p.z) then return false end
                local item=turtle.getItemDetail()
                local ok,err=originalPlace()
                if ok then PY_PLACED(MACHINE_ID,p.x,p.y,p.z,item.name) end
                coroutine.yield(); return ok,err
            end
            for _,side in ipairs({"front","up","down"}) do
                local name=side=="front" and "detect" or (side=="up" and "detectUp" or "detectDown")
                local detector=turtle[name]
                turtle[name]=function()
                    local p=TEST_ENV.adjacent(side)
                    return PY_OCCUPIED(MACHINE_ID,p.x,p.y,p.z) or detector()
                end
                name=side=="front" and "inspect" or (side=="up" and "inspectUp" or "inspectDown")
                local inspector=turtle[name]
                turtle[name]=function()
                    local p=TEST_ENV.adjacent(side)
                    if PY_OCCUPIED(MACHINE_ID,p.x,p.y,p.z) then return true,{name="computercraft:turtle_advanced"} end
                    return inspector()
                end
                name=side=="front" and "dig" or (side=="up" and "digUp" or "digDown")
                local digger=turtle[name]
                turtle[name]=function()
                    local p=TEST_ENV.adjacent(side)
                    local ok,err=digger()
                    if ok then PY_CLEARED(MACHINE_ID,p.x,p.y,p.z) end
                    return ok,err
                end
            end
            for _,entry in ipairs({{"forward","front"},{"back","back"},{"up","up"},{"down","down"}}) do
                local name,side=entry[1],entry[2]; local original=turtle[name]
                turtle[name]=function()
                    local p=TEST_ENV.adjacent(side)
                    if PY_OCCUPIED(MACHINE_ID,p.x,p.y,p.z) then return false end
                    local ok,err=original(); coroutine.yield(); return ok,err
                end
            end
            parallel.waitForAny=function(...)
                local threads={}; for _,fn in ipairs({...}) do threads[#threads+1]=coroutine.create(fn) end
                while true do
                    for _,thread in ipairs(threads) do
                        local ok,err=coroutine.resume(thread); assert(ok,err)
                        if coroutine.status(thread)=="dead" then return end
                        coroutine.yield()
                    end
                end
            end
            WORKER=coroutine.create(function() loadfile(ROOT.."/turtle/worker.lua")("99","0") end)
            STEP=function() local ok,err=coroutine.resume(WORKER); assert(ok,err) end
        ''')

    owners, started, worked_together, startup_overlap, shaft_overlap, opposite_overlap = set(), False, False, False, False, False
    for _ in range(20000):
        clock[0] += 0.05
        for identity in workers:
            machines[identity][0].globals().STEP()
        while queues[99]:
            sender, text, protocol = receive(99)
            main.globals().CONTROL.handle(sender, main.globals().textutils.unserialize(text), protocol)
        main.globals().CONTROL.tick()
        control = main.globals().CONTROL
        owner = control.snapshot()["serviceOwner"]
        if owner is not None:
            owners.add(owner)
        tunnel_owner = control.snapshot()["tunnelOwner"]
        if shaft:
            in_shaft=[machines[i][1]["world"]() for i in workers if 0 < machines[i][1]["world"]()["y"] < 40]
            shaft_overlap = shaft_overlap or len(in_shaft)>=2
            opposite_overlap = opposite_overlap or (any(w["x"]==-1 for w in in_shaft) and any(w["x"]==1 for w in in_shaft))
        if shaft and owner is not None and tunnel_owner is not None and owner != tunnel_owner:
            first_world = machines[tunnel_owner][1]["world"]()
            startup_overlap = startup_overlap or (first_world["y"] > 0 and len(list(first_world["digs"].values())) == 0)
        if not started and len(list(control.available().values())) == worker_count:
            main.globals().WORKER_IDS=main.table_from(workers)
            ok = main.execute('''local a,b={x=8,y=0,z=0},{x=11,y=-19,z=3}
                local tunnel,floor
                if USE_SHAFT then
                    a,b={x=8,y=40,z=0},{x=11,y=21,z=3}
                    tunnel={x=0,z=0,floors={base={exit={x=2,y=0,z=0}},upper={exit={x=2,y=40,z=0}}}}
                    floor="upper"
                end
                if JOB_KIND=="floor" then a,b={x=8,y=-1,z=0},{x=27,y=-1,z=15} end
                return CONTROL.start(a,b,WORKER_IDS,
                {fuel={x=2,y=0,z=2,direction=1,side="front"},output={x=-2,y=0,z=2,direction=3,side="front"},
                materials={x=2,y=0,z=-2,direction=1,side="front"}},tunnel,floor,{kind=JOB_KIND})''')
            assert ok is True, ok
            started = True
        job = control.state["job"]
        counter = "placements" if kind == "floor" else "digs"
        dug_counts = [len(list(machines[i][1]["world"]()[counter].values())) for i in workers]
        worked_together = worked_together or (started and sum(0<n<job["tasks"][i]["total"] for i,n in zip(workers,dug_counts))>=2)
        if started and all(job["tasks"][i]["status"] == "complete" for i in workers):
            break
    else:
        states = {i: control.state["workers"][i]["status"] for i in workers}
        raise AssertionError(f"Fleet did not complete: {states}")
    assert owners == set(workers)
    assert worked_together, "Workers should process their segments concurrently"
    if shaft:
        assert startup_overlap, "Second worker should use service before the first reaches its excavation"
        assert shaft_overlap, "Two workers should travel in separate shaft columns concurrently"
        assert control.snapshot()["tunnelOwner"] is None
    summary = control.snapshot()["summary"]
    assert summary["completed"] == 320 and summary["remaining"] == 0
    mined = set()
    for identity in workers:
        expected_z=-2*(identity-41)
        world = machines[identity][1]["world"]()
        assert (world["x"], world["y"], world["z"]) == (4 if shaft else 0, 0, expected_z)
        if kind == "floor":
            assert len(list(world["digs"].values())) == 0
        for p in world[counter].values():
            point = (p["x"], p["y"], p["z"])
            assert point not in mined
            mined.add(point)
    assert len(mined) == 320
    if kind == "floor":
        assert summary["placed"] == 320 and summary["kind"] == "floor"
    label = f"{kind}, pipelined shaft startup" if shaft else kind
    print(f"PASS radio integration ({label}): {worker_count} concurrent workers, 1 controller, 320 cells and distinct docks", flush=True)
