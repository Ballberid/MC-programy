local env=...
local test,eq,world=env.test,env.eq,env.world
test("normal navigation avoids fuel inventory scans and duplicate detection",function()
    local c=env.configured(); c.telemetry.enabled=false
    assert(require("config").save(c))
    local nav=env.navReady(); local anchor=nav.getPosition()
    local details,detects,inspects=0,0,0
    local detail,detect,inspect=turtle.getItemDetail,turtle.detect,turtle.inspect
    turtle.getItemDetail=function(...) details=details+1; return detail(...) end
    turtle.detect=function(...) detects=detects+1; return detect(...) end
    turtle.inspect=function(...) inspects=inspects+1; return inspect(...) end
    for _=1,15 do assert(nav.step("front",{anchor=anchor,positionVerified=true})) end
    eq(details,0); eq(detects,0); eq(inspects,15)
end)
test("space checks stop early but observe newly filled slots",function()
    local W=world(); local inv=require("inventory")
    local calls=0; local count=turtle.getItemCount
    turtle.getItemCount=function(...) calls=calls+1; return count(...) end
    assert(inv.hasFreeSlots(0)); eq(calls,0)
    assert(inv.hasFreeSlots(2)); eq(calls,2)
    for slot=1,16 do W.slots[slot]={name="minecraft:stone",count=64} end
    eq(inv.hasFreeSlots(2),false)
    calls=0; local p=inv.snapshot(); eq(p.freeSlots,0); eq(#p.items,16); eq(calls,0)
end)
test("navigation preserves movement through a fluid seen by inspect but not detect",function()
    env.configured(); local nav=env.navReady(); local W=world()
    local anchor=nav.getPosition()
    turtle.inspect=function() return true,{name="minecraft:water"} end
    turtle.detect=function() return false end
    assert(nav.step("front",{anchor=anchor,positionVerified=true}))
    eq(W.moves,1); eq(#W.digs,0)
end)
test("refreshing obstacles does not scan the whole explored map",function()
    local paths=require("pathfinding")
    for x=0,2000 do paths.mark({x=x,y=0,z=0},true) end
    paths.mark({x=2001,y=0,z=0},false)
    local visits,originalPairs=0,pairs
    pairs=function(t)
        local nextEntry,state,key=originalPairs(t)
        return function(s,k)
            local newKey,value=nextEntry(s,k)
            if newKey~=nil then visits=visits+1 end
            return newKey,value
        end,state,key
    end
    local ok,err=pcall(paths.forgetBlocked); pairs=originalPairs
    assert(ok,err); assert(visits<10,"Map cells scanned: "..visits)
    assert(paths.find({x=2000,y=0,z=0},{x=2001,y=0,z=0}))
    eq(paths.find({x=2000,y=0,z=0},{x=2001,y=0,z=0},{knownOnly=true}),nil)
    assert(paths.find({x=1999,y=0,z=0},{x=2000,y=0,z=0},{knownOnly=true}))
end)
test("failed telemetry attempts are throttled while critical messages retry immediately",function()
    local attempts=0
    require("network").open=function() attempts=attempts+1; return false,"missing_modem" end
    local t=require("telemetry")
    for _=1,100 do t.emit("info","step") end
    eq(attempts,1)
    sleep(2); t.emit("info","step"); eq(attempts,2)
    t.emit("error","failure",nil,true); eq(attempts,3)
end)
test("worker status bursts are coalesced but pause is reported immediately",function()
    env.configured(); env.navReady()
    local W=world(); local client=require("fleet_client").new(99,{x=0,y=0,z=0,direction=0})
    client.state.status="running"; client.status(true)
    local count=#W.packets
    for _=1,100 do
        client.handle(99,{version=1,kind="discover"}); client.status()
    end
    eq(#W.packets,count)
    sleep(1); client.status(); eq(#W.packets,count+1)
    client.handle(99,{version=1,kind="control",action="pause",request="pause:1",order=1})
    eq(W.packets[#W.packets].status,"paused")
end)
test("verified return cache extends free paths but invalidates blocked, temporary and excluded paths",function()
    local paths=require("pathfinding")
    local goal={x=0,y=0,z=0}
    for x=0,40 do paths.mark({x=x,y=0,z=0},true) end
    local calls=0; local find=paths.find
    paths.find=function(...) calls=calls+1; return find(...) end
    local start={x=40,y=0,z=0}
    eq(paths.knownDistance(start,goal,6000),40)
    local initial=calls
    for _=1,200 do eq(paths.knownDistance(start,goal,6000),40) end
    eq(calls,initial)
    eq(paths.knownDistance({x=41,y=0,z=0},goal,6000),41)
    eq(paths.knownDistance({x=42,y=0,z=0},goal,6000),nil)
    paths.mark({x=41,y=0,z=0},true); eq(paths.knownDistance({x=41,y=0,z=0},goal,6000),41)
    paths.mark({x=20,y=0,z=0},false); eq(paths.knownDistance(start,goal,6000),nil)
    paths.mark({x=20,y=0,z=0},true); eq(paths.knownDistance(start,goal,6000),40)
    paths.markTemporary({x=20,y=0,z=0}); eq(paths.knownDistance(start,goal,6000),nil)
    sleep(6); eq(paths.knownDistance(start,goal,6000),40)
    paths.setAvoid({min={x=20,y=0,z=0},max={x=20,y=0,z=0}}); eq(paths.knownDistance(start,goal,6000),nil)
    paths.setAvoid(nil); eq(paths.knownDistance(start,goal,6000),40)
    paths.clear(); eq(paths.knownDistance(start,goal,6000),nil)
end)
test("job settings cache avoids file reads, observes saves and is removed after errors",function()
    env.configured()
    local cfg=require("config")
    local reads=0; local open=fs.open
    fs.open=function(path,mode) if path=="data/settings.txt" and mode=="r" then reads=reads+1 end; return open(path,mode) end
    local ok=pcall(function() cfg.withCache(function()
        for _=1,100 do assert(cfg.load()) end
        eq(reads,1)
        local c=cfg.load(); c.navigation.reserve=30; assert(cfg.save(c))
        cfg.withCache(function() eq(cfg.load().navigation.reserve,30) end)
        eq(reads,2)
        error("test cleanup")
    end) end)
    eq(ok,false)
    assert(cfg.load()); eq(reads,3); assert(cfg.load()); eq(reads,4)
end)
test("activity telemetry coalesces fast movement changes but forced errors are delivered immediately",function()
    local W=world(); local t=require("telemetry")
    assert(t.setActivity("mining")); local initial=#W.packets
    for _=1,100 do assert(t.setActivity("moving")); assert(t.setActivity("mining")) end
    eq(#W.packets,initial); eq(t.getActivity(),"mining")
    sleep(2); assert(t.setActivity("moving")); eq(#W.packets,initial+1)
    assert(t.emit("error","failure",nil,true)); eq(#W.packets,initial+2)
end)
test("100 block quarry bounds route searches, GPS checks and settings reads",function()
    local W=world(); W.fuel,W.limit=40000,40000
    env.configured({fuel={x=2,y=0,z=0,direction=1,side="front"},output={x=0,y=0,z=2,direction=2,side="front"}})
    W.chests["3,0,0"]={items={{name="minecraft:coal",count=1000}}}; W.chests["0,0,3"]={items={}}
    for x=4,13 do for z=4,13 do W.blocks[x..",0,"..z]=true end end
    local calls,reads=0,0
    local paths=require("pathfinding"); local find=paths.find
    paths.find=function(...) calls=calls+1; return find(...) end
    local open=fs.open
    fs.open=function(path,mode) if path=="data/settings.txt" and mode=="r" then reads=reads+1 end; return open(path,mode) end
    local ok,err,p=require("mining").run({x=4,y=0,z=4},{x=13,y=0,z=13},0)
    assert(ok,err); eq(p.dug,100); eq(p.visited,100); eq(p.returnedHome,true)
    assert(calls<150,"Repeated path searches: "..calls)
    assert(W.gpsCalls>=6 and W.gpsCalls<50,"GPS should be periodic during work: "..W.gpsCalls)
    assert(reads<5,"Repeated settings file reads: "..reads)
    eq(W.lostDrops,0)
end)
test("a due periodic GPS check catches a mismatch before digging",function()
    env.configured(); local nav=env.navReady()
    local c=require("config").load(); c.navigation.gpsEvery=0; nav.configure(c)
    local W=world(); W.x=1; W.blocks["0,0,-1"]=true
    local target={x=0,y=0,z=-1}; local box=assert(require("cuboid").new(target,target))
    local ok=require("mining").stepTo(target,box,{dug=0,completed=0})
    eq(ok,false); eq(#W.digs,0); eq(W.moves,0)
end)
test("tracked work steps use GPS only after sixteen successful moves and stop on GPS loss",function()
    env.configured(); local nav=env.navReady(); local W=world()
    local anchor=nav.getPosition(); local before=W.gpsCalls
    for _=1,15 do assert(nav.step("front",{anchor=anchor,positionVerified=true})) end
    eq(W.gpsCalls,before); eq(W.moves,15); eq(nav.getPosition().z,-15)
    W.gpsFailAt=W.gpsCalls+1
    local ok,err=nav.step("front",{anchor=anchor,positionVerified=true})
    eq(ok,false); eq(err,"gps_unavailable"); eq(W.moves,16); eq(W.gpsCalls,before+1)
end)
test("failed work movement leaves coordinates unchanged and checks GPS immediately",function()
    env.configured(); local nav=env.navReady(); local W=world()
    local anchor=nav.getPosition(); local before=W.gpsCalls
    W.blocks["0,0,-1"]=true
    local ok=nav.step("front",{anchor=anchor,positionVerified=true})
    eq(ok,false); eq(W.moves,0); eq(nav.getPosition().z,0); eq(W.gpsCalls,before+1)
    W.blocks["0,0,-1"]=nil
    for _=1,15 do assert(nav.step("front",{anchor=anchor,positionVerified=true})) end
    eq(W.gpsCalls,before+1)
    assert(nav.step("front",{anchor=anchor,positionVerified=true})); eq(W.gpsCalls,before+2)
end)
