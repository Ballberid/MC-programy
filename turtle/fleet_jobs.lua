-- Job bookkeeping stays on the controller; workers execute their own assignments.
local cuboid=require("cuboid")
local position=require("position")
local model=require("fleet_model")
local jobs={}
function jobs.finished(task)
    return task.status=="complete" or task.status=="cancelled"
end
local function overlap(a,b)
    for _,axis in ipairs({"x","y","z"}) do
        if a.max[axis]<b.min[axis] or b.max[axis]<a.min[axis] then return false end
    end
    return true
end
local function area(job)
    local _,t=next(job.tasks)
    local box=job.area or t.assignment.area or assert(cuboid.new(t.assignment.a,t.assignment.b))
    if job.kind=="floor" or job.kind=="ceiling" then return require("floor_plan").protected(box) end
    return box
end
local function infrastructureIn(box,job)
    for _,t in pairs(job.tasks) do
        local a=t.assignment
        for _,s in pairs(a.stations) do
            if cuboid.contains(box,s) or cuboid.contains(box,position.offset(s,s.direction,s.side)) then return true end
        end
        if a.tunnel then
            local shaft=a.tunnel
            local low,high
            for _,floor in pairs(shaft.floors) do
                local p=floor.exit
                low=math.min(low or p.y,p.y); high=math.max(high or p.y,p.y)
                local corridor={min={x=math.min(p.x,shaft.x),y=p.y,z=math.min(p.z,shaft.z)},
                    max={x=math.max(p.x,shaft.x),y=p.y,z=math.max(p.z,shaft.z)}}
                if overlap(box,corridor) then return true end
            end
            if low and overlap(box,{min={x=shaft.x-1,y=low,z=shaft.z-1},max={x=shaft.x+1,y=high,z=shaft.z+1}}) then return true end
        end
    end
    return false
end
function jobs.new(state)
    state.jobs=state.jobs or {}
    if state.job and not state.jobs[state.job.id] then state.jobs[state.job.id]=state.job end
    state.lastJobId=state.lastJobId or (state.job and state.job.id)
    state.jobSerial=state.jobSerial or 0
    local byTask={}
    for _,job in pairs(state.jobs) do
        if not job.number then state.jobSerial=state.jobSerial+1; job.number=state.jobSerial end
        state.jobSerial=math.max(state.jobSerial,job.number)
        for _,t in pairs(job.tasks) do byTask[t.id]={task=t,job=job} end
    end
    state.job=state.jobs[state.lastJobId] -- Compatibility for callers reading the last job.
    local self={}
    function self.task(worker)
        local w=state.workers[worker]
        local entry=w and byTask[w.taskId]
        if entry then return entry.task,entry.job end
    end
    function self.conflict(candidate,replaced)
        local target=area(candidate)
        for _,old in pairs(state.jobs) do
            local unfinished=false
            for id,t in pairs(old.tasks) do
                if not jobs.finished(t) and not (replaced[id] and t.status=="failed") then unfinished=true; break end
            end
            if unfinished then
                local previous=area(old)
                if overlap(target,previous) then return "job_area_conflict:"..old.number end
                if infrastructureIn(target,old) or infrastructureIn(previous,candidate) then
                    return "job_infrastructure_conflict:"..old.number
                end
            end
        end
    end
    function self.add(job)
        state.jobSerial=state.jobSerial+1; job.number=state.jobSerial
        for id in pairs(job.tasks) do
            local old=self.task(id)
            if old and not jobs.finished(old) then old.status="cancelled" end
        end
        state.jobs[job.id]=job; state.lastJobId=job.id; state.job=job
        for _,t in pairs(job.tasks) do byTask[t.id]={task=t,job=job} end
    end
    function self.prune()
        -- Retain jobs still referenced by a worker; drop retired history to bound saves.
        for id,job in pairs(state.jobs) do
            local keep=id==state.lastJobId
            for worker,t in pairs(job.tasks) do
                if not jobs.finished(t) or (state.workers[worker] and state.workers[worker].taskId==t.id) then keep=true end
            end
            if not keep then
                for _,t in pairs(job.tasks) do byTask[t.id]=nil end
                state.jobs[id]=nil
            end
        end
    end
    function self.snapshot()
        local list={}
        local total={total=0,completed=0,remaining=0,dug=0,placed=0,skipped=0,active=0,failed=0,jobs=0,activeJobs=0}
        for _,job in pairs(state.jobs) do
            local s=model.summary(job)
            local ids={}; for id in pairs(job.tasks) do ids[#ids+1]=id end; table.sort(ids)
            local status=s.active>0 and "running" or (s.failed>0 and "failed" or (s.completed==s.total and "complete" or "cancelled"))
            list[#list+1]={id=job.id,number=job.number,kind=job.kind or "quarry",workers=ids,summary=s,status=status}
            for _,key in ipairs({"total","completed","remaining","dug","placed","skipped","active","failed"}) do
                total[key]=total[key]+s[key]
            end
            total.jobs=total.jobs+1
            if s.active>0 or s.failed>0 then total.activeJobs=total.activeJobs+1 end
            local kind=job.kind or "quarry"
            total.kind=not total.kind and kind or (total.kind==kind and kind or "mixed")
        end
        table.sort(list,function(a,b) return a.number<b.number end)
        return list,total
    end
    return self
end
return jobs
