-- Small per-job timings, saved in batches rather than for every mined block.
local timing={}
local totals,active,last
local function now() return os.epoch("utc")/1000 end
function timing.reset()
    totals={steps=0,seconds=0,supplies=0,checks=0,dig=0,move=0}; active=nil; last=nil
end
function timing.phase(name)
    if not active then return end
    local time=now()
    active[active.phase]=active[active.phase]+math.max(0,time-active.since)
    active.phase,active.since=name,time
end
function timing.flush()
    if not totals or totals.steps==0 then return end
    -- Diagnostics must not interrupt work if their file cannot be written.
    pcall(function()
        fs.makeDir("data")
        local f=fs.open("data/mining-speed.txt","w")
        if f then
            f.write(textutils.serialize({time=os.epoch("utc"),totals=totals,last=last})); f.close()
        end
    end)
end
function timing.measure(fn,...)
    if not totals then timing.reset() end
    local start=now()
    active={phase="checks",since=start,supplies=0,checks=0,dig=0,move=0}
    local result=table.pack(pcall(fn,...))
    timing.phase("checks")
    last={seconds=math.max(0,now()-start),ok=result[1] and result[2]==true}
    totals.steps=totals.steps+1; totals.seconds=totals.seconds+last.seconds
    for _,name in ipairs({"supplies","checks","dig","move"}) do
        last[name]=active[name]; totals[name]=totals[name]+active[name]
    end
    active=nil
    if totals.steps%32==0 or not last.ok then timing.flush() end
    if not result[1] then error(result[2],0) end
    return table.unpack(result,2,result.n)
end
function timing.read()
    local f=fs.open("data/mining-speed.txt","r")
    if not f then return nil,"Zatial nie je zaznam; ulozi sa po 32 krokoch alebo na konci ulohy." end
    local text=f.readAll(); f.close()
    local ok,data=pcall(textutils.unserialize,text)
    if not ok or type(data)~="table" or type(data.totals)~="table" then return nil,"Poskodeny zaznam merania." end
    for _,name in ipairs({"steps","seconds","supplies","checks","dig","move"}) do
        if type(data.totals[name])~="number" or data.totals[name]<0 then return nil,"Poskodeny zaznam merania." end
    end
    if data.totals.steps<1 or type(data.time)~="number" then return nil,"Poskodeny zaznam merania." end
    return data
end
return timing
