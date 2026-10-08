"""Exercise two isolated CC workers against one controller over a queued radio."""
from collections import deque


def run(root, runtime_type, kind="quarry", shaft=False, worker_count=2, mixed=False, corners=False, recovery=False, restock=False, interior=False):
    prefix = (root / "tests" / "turtle_spec.lua").read_text(encoding="utf-8")
    prefix = prefix[:prefix.index('test("targeted refuel')]
    workers=tuple(range(41,41+worker_count))
    queues = {identity:deque() for identity in (99,*workers)}
    machines = {}
    clock = [0.0]
    departures=[]
    radio_errors=[]

    def departure_safe(machine):
        control=machines[99][0].globals().CONTROL
        claim=control.state["locks"]["station:2,0,2"]
        assert claim and claim["owner"]==machine, "Workers must reserve their first chest before leaving the dock"
        for identity in workers:
            if identity==machine: continue
            world=machines[identity][1]["world"]()
            assert (world["x"],world["y"],world["z"])!=(2,0,2), "Departure must wait until the first chest is physically free"
        departures.append(machine)

    def send(source, recipient, message, protocol):
        if protocol=="craftoria.turtle.v1" and '["level"]="error"' in message:
            radio_errors.append(message)
            if len(radio_errors)>8: radio_errors.pop(0)
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
                world=env["world"]()
                world["blocks"][key],world["blockNames"][key] = None,None

    def placed(machine, x, y, z, name):
        key = f"{x},{y},{z}"
        for identity, (_, env) in machines.items():
            if identity != 99 and identity != machine:
                world = env["world"]()
                world["blocks"][key], world["blockNames"][key] = True, name

    def gate_safe(machine):
        for identity in workers:
            if identity==machine: continue
            world=machines[identity][1]["world"]()
            assert (world["x"],world["y"],world["z"])==(0,0,-2*(identity-41)), "Cannot close the opening before the other turtles reach their docks"

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
        lua.globals().PY_GATE_SAFE = gate_safe
        lua.globals().PY_DEPARTURE_SAFE = departure_safe
        lua.globals().JOB_KIND = kind
        lua.globals().MIXED_JOBS = mixed
        lua.globals().USE_SHAFT = shaft
        lua.globals().WALL_CORNERS = corners
        lua.globals().WALL_RECOVERY = recovery
        lua.globals().WALL_RESTOCK = restock
        lua.globals().WALL_INTERIOR = interior
        lua.globals().WALL_EXIT_Y = 22 if interior == "above" else (3 if interior == "below" else 6)
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
            if JOB_KIND=="quarry" or MIXED_JOBS then
                local bottom,top=USE_SHAFT and 21 or -19,USE_SHAFT and 40 or 0
                for x=8,11 do for y=bottom,top do for z=0,3 do W.blocks[x..","..y..","..z]=true end end end
                if USE_SHAFT then
                    for x=-20,30 do for z=-20,20 do
                        if math.abs(x)>1 or math.abs(z)>1 then W.blocks[x..",20,"..z]=true end
                    end end
                end
            else W.fuel,W.limit=20000,40000 end
            if JOB_KIND=="walls" then
                -- An excavated room in solid earth, accessible at one opening.
                for x=7,18 do for y=-1,4 do for z=-1,10 do
                    if x<=8 or x>=17 or z<=0 or z>=9 or y<0 or y>3 then
                        local k=x..","..y..","..z
                        W.blocks[k],W.blockNames[k]=true,"minecraft:dirt"
                    end
                end end end
                W.blocks["7,1,1"],W.blockNames["7,1,1"]=nil,nil
                if WALL_CORNERS then
                    -- Corners explicitly require outside access.
                    for x=7,18 do for y=0,3 do for z=-1,10 do
                        if x==7 or x==18 or z==-1 or z==10 then
                            local k=x..","..y..","..z; W.blocks[k],W.blockNames[k]=nil,nil
                        end
                    end end end
                end
                if WALL_INTERIOR then
                    local blocks,names={},{}
                    for k,value in pairs(W.blocks) do
                        local x,y,z=k:match("^(%-?%d+),(%-?%d+),(%-?%d+)$")
                        local moved=x..","..(tonumber(y)+5)..","..z
                        blocks[moved],names[moved]=value,W.blockNames[k]
                    end
                    W.blocks,W.blockNames=blocks,names
                    -- No access to the old outside gate: use the shaft inside.
                    W.blocks["7,6,1"],W.blockNames["7,6,1"]=true,"minecraft:dirt"
                    for x=11,13 do for z=3,5 do
                        W.blocks[x..",4,"..z],W.blockNames[x..",4,"..z]=nil,nil
                        W.blocks[x..",9,"..z],W.blockNames[x..",9,"..z]=nil,nil
                    end end
                end
            end
            if MIXED_JOBS then W.fuel,W.limit=20000,40000 end
            for _,entry in ipairs({{"placeDown","down"},{"placeUp","up"},{"place","front"}}) do
            local name,side=entry[1],entry[2]
            local originalPlace=turtle[name]
            turtle[name]=function()
                local p=TEST_ENV.adjacent(side)
                if PY_OCCUPIED(MACHINE_ID,p.x,p.y,p.z) then return false end
                if JOB_KIND=="walls" and WALL_RECOVERY and MACHINE_ID==41 and #W.placements>=8 and not W.injectedFailure then
                    W.injectedFailure=true; return false,"temporary_test_obstruction"
                end
                if JOB_KIND=="walls" and not WALL_INTERIOR and p.x==8 and p.y==1 and p.z==1 then PY_GATE_SAFE(MACHINE_ID) end
                local item=turtle.getItemDetail()
                local ok,err=originalPlace()
                if ok then PY_PLACED(MACHINE_ID,p.x,p.y,p.z,item.name) end
                coroutine.yield(); return ok,err
            end
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
                    local ok,err=original()
                    if ok and WALL_RESTOCK and p.x==2 and p.y==0 and p.z==-2 then
                        W.materialVisits=(W.materialVisits or 0)+1
                        W.chests["3,0,-2"].items={{name="minecraft:stone",count=8}}
                    end
                    if ok and not FIRST_MOVE then
                        PY_DEPARTURE_SAFE(MACHINE_ID)
                        FIRST_MOVE={x=p.x,y=p.y,z=p.z}; FIRST_MOVE_AT=os.clock()
                    end
                    coroutine.yield(); return ok,err
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

    second_started=False
    silent_ticks=0
    autonomy_started=False
    autonomy_confirmed=False
    restarted=False
    autonomy_before=None
    resumed=False
    owners, started, worked_together, startup_overlap, shaft_overlap, opposite_overlap = set(), False, False, False, False, False
    for _ in range(20000):
        clock[0] += 0.05
        for identity in workers:
            machines[identity][0].globals().STEP()
        if silent_ticks:
            silent_ticks-=1
            if silent_ticks==0:
                after=[len(list(machines[i][1]["world"]()["digs" if i==41 else "placements"].values())) for i in workers]
                assert all(a>b for a,b in zip(after,autonomy_before)), "Workers need to keep working without controller replies"
                autonomy_confirmed=True
        else:
            while queues[99]:
                sender, text, protocol = receive(99)
                main.globals().CONTROL.handle(sender, main.globals().textutils.unserialize(text), protocol)
            main.globals().CONTROL.tick()
        if mixed and autonomy_confirmed and not restarted:
            main.execute('CONTROL=require("fleet_controller").new(require("fleet_settings").defaults())')
            restarted=True
        control = main.globals().CONTROL
        if recovery and not resumed and control.state["workers"][41] and control.state["workers"][41]["status"]=="failed":
            assert machines[41][1]["world"]()["blockNames"]["8,1,1"]!="minecraft:stone", "Failure must leave the shared opening usable"
            main.execute('CONTROL=require("fleet_controller").new(require("fleet_settings").defaults()); CONTROL.control("resume",41)')
            control=main.globals().CONTROL
            resumed=True
        snapshot=control.snapshot()
        owner = snapshot["serviceOwner"]
        owners.update(snapshot["serviceOwners"].values())
        tunnel_owner = control.snapshot()["tunnelOwner"]
        if shaft:
            in_shaft=[machines[i][1]["world"]() for i in workers if 0 < machines[i][1]["world"]()["y"] < 40]
            shaft_overlap = shaft_overlap or len(in_shaft)>=2
            opposite_overlap = opposite_overlap or (any(w["x"]==-1 for w in in_shaft) and any(w["x"]==1 for w in in_shaft))
        if shaft and owner is not None and tunnel_owner is not None and owner != tunnel_owner:
            first_world = machines[tunnel_owner][1]["world"]()
            startup_overlap = startup_overlap or (first_world["y"] > 0 and len(list(first_world["digs"].values())) == 0)
        if not started and len(list(control.available().values())) == worker_count:
            main.globals().WORKER_IDS=main.table_from((41,) if mixed else workers)
            ok = main.execute('''local a,b={x=8,y=0,z=0},{x=11,y=-19,z=3}
                local tunnel,floor
                if USE_SHAFT then
                    a,b={x=8,y=40,z=0},{x=11,y=21,z=3}
                    tunnel={x=0,z=0,floors={base={exit={x=2,y=0,z=0}},upper={exit={x=2,y=40,z=0}}}}
                    floor="upper"
                end
                if JOB_KIND=="floor" then a,b={x=8,y=-1,z=0},{x=27,y=-1,z=15} end
                if JOB_KIND=="ceiling" then a,b={x=8,y=1,z=0},{x=27,y=1,z=15} end
                if JOB_KIND=="walls" then a,b={x=8,y=0,z=0},{x=17,y=3,z=9} end
                if WALL_INTERIOR then
                    a,b={x=8,y=5,z=0},{x=17,y=8,z=9}
                    tunnel={x=12,z=4,floors={base={exit={x=14,y=0,z=4}},upper={exit={x=14,y=WALL_EXIT_Y,z=4}}}}
                    floor="upper"
                end
                return CONTROL.start(a,b,WORKER_IDS,
                {fuel={x=2,y=0,z=2,direction=1,side="front"},output={x=-2,y=0,z=2,direction=3,side="front"},
                materials={x=2,y=0,z=-2,direction=1,side="front"}},tunnel,floor,{kind=JOB_KIND,includeCorners=WALL_CORNERS})''')
            assert ok is True, ok
            started = True
        if mixed and started and not second_started and len(list(machines[41][1]["world"]()["digs"].values()))>=5:
            assert control.state["workers"][41]["status"]=="running"
            ok=main.execute('''return CONTROL.start({x=16,y=-1,z=0},{x=35,y=-1,z=15},{42},
                {fuel={x=2,y=0,z=2,direction=1,side="front"},output={x=-2,y=0,z=2,direction=3,side="front"},
                materials={x=2,y=0,z=-2,direction=1,side="front"}},nil,nil,{kind="floor"})''')
            assert ok is True,ok
            second_started=True
        tasks={i:t for job in control.state["jobs"].values() for i,t in job["tasks"].items()}
        def counter_for(i):
            return "placements" if kind in ("floor","ceiling","walls") or (mixed and i==42) else "digs"
        dug_counts = [len(list(machines[i][1]["world"]()[counter_for(i)].values())) for i in workers]
        if mixed and second_started and not autonomy_started and all(5<n<100 for n in dug_counts):
            autonomy_started=True
            autonomy_before=dug_counts[:]
            silent_ticks=160  # Eight simulated seconds with no coordinator replies.
        worked_together = worked_together or (started and sum(i in tasks and 0<n<tasks[i]["total"] for i,n in zip(workers,dug_counts))>=2)
        if started and all(i in tasks and tasks[i]["status"] == "complete" for i in workers):
            break
    else:
        states = {i: control.state["workers"][i]["status"] for i in workers}
        positions={i:tuple(machines[i][1]["world"]()[k] for k in ("x","y","z")) for i in workers}
        failures={i:control.state["workers"][i]["error"] for i in workers}
        for message in radio_errors[-5:]: print(message, flush=True)
        raise AssertionError(f"Fleet did not complete: {states}, positions={positions}, errors={failures}")
    assert owners == set(workers)
    for index,identity in enumerate(workers):
        first=machines[identity][0].globals().FIRST_MOVE
        assert (first["x"],first["y"],first["z"]) == (4 if shaft else 0,0,-2*index-1), "Dock departure must first move forward"
    assert departures==list(workers), "Workers must depart in assignment order as the first chest becomes free"
    assert worked_together, "Workers should process their segments concurrently"
    if shaft:
        assert startup_overlap, "Second worker should use service before the first reaches its excavation"
        assert shaft_overlap, "Two workers should travel in separate shaft columns concurrently"
        assert control.snapshot()["tunnelOwner"] is None
    summary = control.snapshot()["summary"]
    expected = (144 if corners else 128) if kind=="walls" else (640 if mixed else 320)
    assert summary["completed"] == expected and summary["remaining"] == 0
    mined = set()
    for identity in workers:
        expected_z=-2*(identity-41)
        world = machines[identity][1]["world"]()
        assert (world["x"], world["y"], world["z"]) == (4 if shaft else 0, 0, expected_z)
        if kind in ("floor", "ceiling"):
            assert len(list(world["digs"].values())) == 0
        for p in world[counter_for(identity)].values():
            point = (p["x"], p["y"], p["z"])
            assert point not in mined
            mined.add(point)
    assert len(mined) == expected
    if kind in ("floor", "ceiling", "walls"):
        assert summary["kind"] == kind
        if recovery:
            assert summary["placed"]+summary["skipped"]==expected
        else: assert summary["placed"] == expected
    if kind=="walls":
        if recovery: assert resumed, "The failed worker must resume after a coordinator restart"
        for x,y,z in mined:
            assert 8<=x<=17 and (5 if interior else 0)<=y<=(8 if interior else 3) and 0<=z<=9
            assert x in (8,17) or z in (0,9)
            if not corners: assert not (x in (8,17) and z in (0,9))
        for identity in workers:
            world=machines[identity][1]["world"]()
            for p in world["digs"].values():
                assert (p["x"],p["y"],p["z"]) in mined, "No demolition outside the requested walls"
            gate_key="8,6,1" if interior else "8,1,1"
            assert world["blockNames"][gate_key]=="minecraft:stone", "The last wall block must be completed"
            if interior: assert world["blockNames"]["7,6,1"]=="minecraft:dirt", "No exterior doorway may be dug"
            if restock: assert world["materialVisits"]>=4, "Workers must return through the shared gate for repeated material trips"
        assert not list(control.state["locks"].values()), "All doorway and station locks must be released"
    if mixed:
        assert second_started and autonomy_confirmed and restarted and summary["kind"]=="mixed" and summary["placed"]==320
        assert len(list(control.state["jobs"].values()))==2
    label = "mixed quarry + floor, 640 cells" if mixed else (f"{kind}, pipelined shaft startup" if shaft else kind)
    if recovery: label += ", worker retry and controller restart"
    if restock: label += ", repeated material trips"
    if interior: label += ", tunnel exit " + (interior if isinstance(interior, str) else "inside room")
    print(f"PASS radio integration ({label}): {worker_count} concurrent workers, 1 controller, {expected} cells and distinct docks", flush=True)
