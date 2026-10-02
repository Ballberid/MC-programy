"""Exercise two isolated CC workers against one controller over a queued radio."""
from collections import deque


def run(root, runtime_type, kind="quarry"):
    prefix = (root / "tests" / "turtle_spec.lua").read_text(encoding="utf-8")
    prefix = prefix[:prefix.index('test("targeted refuel')]
    queues = {99: deque(), 41: deque(), 42: deque()}
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
    for identity in (41, 42):
        lua = machines[identity][0]
        lua.execute('''
            local W=TEST_ENV.world()
            W.z = MACHINE_ID==41 and 0 or -2
            local c=TEST_ENV.configured({fuel={x=2,y=0,z=2,direction=1,side="front"},
                output={x=-2,y=0,z=2,direction=3,side="front"},
                materials={x=2,y=0,z=-2,direction=1,side="front"}})
            c.start={x=0,y=0,z=W.z,direction=0}; c.home=c.start
            assert(require("config").save(c))
            W.chests["3,0,2"]={items={{name="minecraft:coal",count=64}}}
            W.chests["-3,0,2"]={items={}}
            W.chests["3,0,-2"]={items={{name="minecraft:stone",count=640}}}
            if JOB_KIND=="quarry" then
                for x=8,11 do for y=-19,0 do for z=0,3 do W.blocks[x..","..y..","..z]=true end end end
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

    owners, started, worked_together = set(), False, False
    for _ in range(20000):
        clock[0] += 0.05
        for identity in (41, 42):
            machines[identity][0].globals().STEP()
        while queues[99]:
            sender, text, protocol = receive(99)
            main.globals().CONTROL.handle(sender, main.globals().textutils.unserialize(text), protocol)
        main.globals().CONTROL.tick()
        control = main.globals().CONTROL
        owner = control.snapshot()["serviceOwner"]
        if owner is not None:
            owners.add(owner)
        if not started and len(list(control.available().values())) == 2:
            ok = main.execute('''local a,b={x=8,y=0,z=0},{x=11,y=-19,z=3}
                if JOB_KIND=="floor" then a,b={x=8,y=-1,z=0},{x=27,y=-1,z=15} end
                return CONTROL.start(a,b,{41,42},
                {fuel={x=2,y=0,z=2,direction=1,side="front"},output={x=-2,y=0,z=2,direction=3,side="front"},
                materials={x=2,y=0,z=-2,direction=1,side="front"}},nil,nil,{kind=JOB_KIND})''')
            assert ok is True, ok
            started = True
        job = control.state["job"]
        counter = "placements" if kind == "floor" else "digs"
        dug_counts = [len(list(machines[i][1]["world"]()[counter].values())) for i in (41, 42)]
        worked_together = worked_together or all(0 < n < 160 for n in dug_counts)
        if started and all(job["tasks"][i]["status"] == "complete" for i in (41, 42)):
            break
    else:
        states = {i: control.state["workers"][i]["status"] for i in (41, 42)}
        raise AssertionError(f"Fleet did not complete: {states}")
    assert owners == {41, 42}
    assert worked_together, "Workers should process their segments concurrently"
    summary = control.snapshot()["summary"]
    assert summary["completed"] == 320 and summary["remaining"] == 0
    mined = set()
    for identity, expected_z in ((41, 0), (42, -2)):
        world = machines[identity][1]["world"]()
        assert (world["x"], world["y"], world["z"]) == (0, 0, expected_z)
        if kind == "floor":
            assert len(list(world["digs"].values())) == 0
        for p in world[counter].values():
            point = (p["x"], p["y"], p["z"])
            assert point not in mined
            mined.add(point)
    assert len(mined) == 320
    if kind == "floor":
        assert summary["placed"] == 320 and summary["kind"] == "floor"
    print(f"PASS radio integration ({kind}): 2 concurrent workers, 1 controller, 320 cells and distinct docks", flush=True)
