"""Opposite-direction shaft travel with isolated Lua maps and real collisions."""
def run(root, runtime_type, wide=False, count=2):
    prefix=(root/"tests"/"turtle_spec.lua").read_text(encoding="utf-8")
    prefix=prefix[:prefix.index('test("targeted refuel')]
    machines,locks={},{}
    clock=[0.0]; used=set()
    def occupied(identity,x,y,z):
        return any(other!=identity and (env["world"]()["x"],env["world"]()["y"],env["world"]()["z"])==(x,y,z)
                   for other,(_,env) in machines.items())
    def acquire(identity,resource):
        if resource=="tunnel:pool":
            for key,owner in locks.items():
                if key.startswith("tunnel:lane:") and owner==identity: return True,None,key
            for index in range(1,10):
                key=f"tunnel:lane:{index}"
                if key not in locks:
                    locks[key]=identity; used.add(index); return True,None,key
            return False,None,None
        if resource in locks and locks[resource]!=identity:
            return False,None,resource
        locks[resource]=identity
        return True,None,resource
    def release(identity,resource):
        assert locks[resource]==identity
        del locks[resource]
    for identity in range(41,41+count):
        lua=runtime_type(unpack_returned_tuples=True)
        lua.globals().ROOT=root.as_posix()
        env=lua.execute(prefix+'\nreset(); return {world=function() return W end,configured=configured,adjacent=adjacent}')
        machines[identity]=(lua,env)
        lua.globals().WIDE=wide
        for key,value in {"ENV":env,"ID":identity,"OCCUPIED":occupied,"TAKE":acquire,"RELEASE":release,"CLOCK":lambda:clock[0]}.items():
            lua.globals()[key]=value
        lua.execute('''
            os.getComputerID=function() return ID end
            os.clock=function() return CLOCK() end
            sleep=function() coroutine.yield() end
            local W=ENV.world(); W.x,W.y,W.z=4+(ID-41)*2,(ID-41)%2==0 and 0 or 40,0; W.fuel,W.limit=5000,40000
            ENV.configured({})
            for x=-20,20 do for z=-20,20 do
                if math.abs(x)>1 or math.abs(z)>1 then W.blocks[x..",20,"..z]=true end
            end end
            for _,side in ipairs({"front","up","down"}) do
                local name=side=="front" and "inspect" or (side=="up" and "inspectUp" or "inspectDown")
                local inspect=turtle[name]
                turtle[name]=function()
                    local p=ENV.adjacent(side)
                    if OCCUPIED(ID,p.x,p.y,p.z) then return true,{name="computercraft:turtle_advanced"} end
                    return inspect()
                end
                name=side=="front" and "detect" or (side=="up" and "detectUp" or "detectDown")
                local detect=turtle[name]
                turtle[name]=function()
                    local p=ENV.adjacent(side); return OCCUPIED(ID,p.x,p.y,p.z) or detect()
                end
            end
            for _,entry in ipairs({{"forward","front"},{"up","up"},{"down","down"}}) do
                local name,side=entry[1],entry[2]; local move=turtle[name]
                turtle[name]=function()
                    local p=ENV.adjacent(side)
                    assert(not OCCUPIED(ID,p.x,p.y,p.z),"traffic attempted an occupied cell")
                    local ok,err=move(); coroutine.yield(); return ok,err
                end
            end
            local nav,transit=require("navigation"),require("transit")
            assert(nav.init(0))
            assert(transit.configure({x=0,z=0,wide=WIDE,floors={base={exit={x=2,y=0,z=0}},upper={exit={x=2,y=40,z=0}}}},nil,(ID-41)%2==0 and "upper" or "base"))
            GO=coroutine.create(function()
                local start=nav.getPosition()
                local ok,err=transit.move({x=W.x,y=(ID-41)%2==0 and 40 or 0,z=0},{anchor=start,reserve=20},
                    function(x,y,z,o) return nav.moveToCoord(x,y,z,o) end,
                    function(r) while true do local ok,_,key=TAKE(ID,r); if ok then return true,nil,key end; coroutine.yield() end end,
                    function(r) RELEASE(ID,r) end,nav.getPosition)
                assert(ok,err)
            end)
            STEP=function() if coroutine.status(GO)~="dead" then local ok,err=coroutine.resume(GO); assert(ok,err) end end
            DONE=function() return coroutine.status(GO)=="dead" end
        ''')
    crossed=False
    for _ in range(10000):
        clock[0]+=0.05
        for lua,_ in machines.values(): lua.globals().STEP()
        up,down=(machines[i][1]["world"]() for i in (41,42))
        crossed=crossed or (up["x"]==-1 and down["x"]==1 and 0<up["y"]<40 and 0<down["y"]<40)
        if all(lua.globals().DONE() for lua,_ in machines.values()): break
    else:
        positions={i:(e["world"]()["x"],e["world"]()["y"],e["world"]()["z"]) for i,(_,e) in machines.items()}
        raise AssertionError(f"Opposite-direction shaft traffic deadlocked: {positions}, locks={locks}")
    assert not locks
    if wide: assert used==set(range(1,count+1)), "Every available shaft column should be assigned"
    else: assert crossed
    for identity in range(41,41+count):
        y=40 if (identity-41)%2==0 else 0
        w=machines[identity][1]["world"](); assert (w["x"],w["y"],w["z"])==(4+(identity-41)*2,y,0)
    print(f"PASS opposite-direction traffic: {count} workers, {'nine allocated' if wide else 'legacy'} columns, no collision or deadlock",flush=True)
