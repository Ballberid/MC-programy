local model = require("fleet_model")
local store = require("fleet_store")
local cuboid = require("cuboid")
local taskLib = require("fleet_task")
local controller = {}
local path = "data/fleet-state.txt"
function controller.new(settings)
    local state = store.load(path, { version = 1, workers = {}, locks = {}, serial = 0 })
    state.workers, state.locks = state.workers or {}, state.locks or {}
    state.pendingControls = state.pendingControls or {}
    local migrating=state.version~=2
    state.version=2
    local jobs=require("fleet_jobs").new(state)
    -- Clock values from before reboot cannot represent current availability.
    for _, w in pairs(state.workers) do w.received = -1000000000 end
    local self = { state = state, settings = settings, lastView = -math.huge, lastDiscover = -math.huge, lastDispatch = -math.huge, lastControl = -math.huge }
    self.dirty=migrating
    function self.save()
        local saved={}; for key,value in pairs(state) do if key~="job" then saved[key]=value end end
        store.save(path,saved); self.dirty=false
    end
    local function updateProgress(t,p)
        local old=t.progress or {}
        local current=model.updateProgress(t,p)
        for key,value in pairs(current or {}) do
            if old[key]~=value then self.dirty=true; break end
        end
        return current
    end
    function self.send(id, kind, extra)
        local p = extra or {}; p.version, p.kind, p.id = 1, kind, os.getComputerID()
        if id then rednet.send(id, p, model.protocol) else rednet.broadcast(p, model.protocol) end
    end
    function self.available()
        local ids = {}
        for id, w in pairs(state.workers) do
            local reserved=false
            for _,lock in pairs(state.locks) do if lock.owner==id then reserved=true; break end end
            local t=jobs.task(id)
            local free=not t or t.status=="complete" or t.status=="failed" or t.status=="cancelled"
            if free and not reserved and not state.pendingControls[id] and os.clock()-w.received<6
                and (w.status=="idle" or w.status=="complete" or w.status=="failed") then ids[#ids+1]=id end
        end
        table.sort(ids); return ids
    end
    function self.start(a, b, ids, stations, tunnel, floor, options)
        options = options or {}
        local kind = options.kind or "quarry"
        if kind ~= "quarry" and kind ~= "floor" and kind ~= "ceiling" and kind ~= "walls" then return false, "invalid_task_kind" end
        if kind == "floor" or kind == "ceiling" then
            local valid, invalid = (kind=="ceiling" and require("ceiling_plan") or require("floor_plan")).new(a, b)
            if not valid then return false, invalid end
        end
        local segments,err,wallArea
        if kind=="walls" then segments,err,wallArea=model.splitWalls(a,b,#ids,options)
        else segments,err=model.split(a,b,#ids) end
        if not segments then return false, err end
        local available, seen = {}, {}
        for _, id in ipairs(self.available()) do available[id] = true end
        state.serial = (state.serial or 0) + 1
        local jobId = tostring(os.getComputerID()) .. ":" .. tostring(os.epoch("utc")) .. ":" .. state.serial
        local area = wallArea or assert(cuboid.new(a, b))
        local protected = (kind == "floor" or kind == "ceiling") and require("floor_plan").protected(area) or area
        for id, w in pairs(state.workers) do
            if cuboid.contains(protected, w.dock) then return false, "dock_inside_area:" .. id end
        end
        local job = { id = jobId, kind = kind, area=area, total = area.volume, tasks = {} }
        if kind=="walls" then job.closer=ids[#ids] end
        for index, id in ipairs(ids) do
            if seen[id] or not available[id] then return false, "worker_unavailable:" .. tostring(id) end
            seen[id] = true
            local s = segments[index]
            local assignment = { id = jobId .. ":" .. index, jobId = jobId, a = s.a, b = s.b,
                area = area, stations = store.copy(stations), tunnel = store.copy(tunnel), floor = floor,
                kind = kind, block = options.block, wallOptions=store.copy(s.wallOptions), lane=(index-1)%2+1, startDelay=(index-1)*5 }
            local c, invalid = taskLib.settings(assignment, state.workers[id].dock)
            if not c then return false, invalid end
            job.tasks[id] = { id = assignment.id, total = s.total, status = "assigned", assignment = assignment }
        end
        local conflict=jobs.conflict(job,seen)
        if conflict then return false,conflict end
        jobs.add(job)
        for id, t in pairs(job.tasks) do
            local w = state.workers[id]; w.status, w.taskId, w.error = "assigned", t.id, nil
            state.pendingControls[id] = nil
            w.packet = { activity = "assigned", message = "Cakam na potvrdenie", fuel = w.packet and w.packet.fuel,
                inventory = w.packet and w.packet.inventory, position = w.packet and w.packet.position }
        end
        jobs.prune()
        self.save()
        for id, t in pairs(job.tasks) do self.send(id, "assign", { task = t.assignment }) end
        return true
    end
    function self.handle(sender, p, protocol)
        if type(p) ~= "table" or p.version ~= 1 or p.id ~= sender then return end
        if protocol == model.telemetryProtocol then
            local w = state.workers[sender]
            if not w or type(p.message) ~= "string" or #p.message > 4096 then return end
            local t = jobs.task(sender)
            local packetTask=type(p.context)=="table" and p.context.taskId or nil
            if packetTask~=w.taskId then return end
            if t then p.progress = updateProgress(t, p.progress) end
            w.packet, w.received = p, os.clock()
            return
        end
        if protocol ~= model.protocol then return end
        if p.kind == "status" then
            if type(p.status) ~= "string" or not require("config").isPoint(p.dock) then return end
            if not state.workers[sender] then
                local count = 0; for _ in pairs(state.workers) do count = count + 1 end
                if count >= 32 then return end
            end
            local w = state.workers[sender] or {}; state.workers[sender] = w
            local t = jobs.task(sender)
            if w.received and p.taskId and p.taskId~=w.taskId then return end
            if t and p.taskId~=t.id then
                -- Ignore late packets from a superseded assignment, including completed jobs.
                if p.taskId or (t.status~="complete" and t.status~="failed" and t.status~="cancelled") then
                    w.received=os.clock(); return
                end
            end
            local dock=w.dock or {}
            if w.status~=p.status or w.taskId~=p.taskId or w.label~=p.label or w.error~=p.error
                or dock.x~=p.dock.x or dock.y~=p.dock.y or dock.z~=p.dock.z or dock.direction~=p.dock.direction then
                self.dirty=true
            end
            w.status, w.received, w.dock, w.label, w.error, w.taskId = p.status, os.clock(), p.dock, p.label, p.error, p.taskId
            w.taskType=p.taskId and (p.taskType or (t and t.id==p.taskId and (t.assignment.kind or "quarry"))) or nil
            w.packet = { activity = p.activity or p.status, level = p.error and "error" or "info", message = p.error or p.activity or p.status,
                label = p.label, fuel = p.fuel, inventory = p.inventory, position = p.position, progress = p.progress }
            if t and p.taskId == t.id then
                local changed = t.status ~= p.status
                t.status, t.error = p.status, p.error
                w.packet.progress = updateProgress(t, p.progress)
                if changed then self.save() end
            end
        elseif p.kind == "reject" then
            local t = jobs.task(sender)
            if t and t.id == p.taskId then
                t.status, t.error = "failed", p.error
                state.workers[sender].status, state.workers[sender].error = "recovery", p.error
                self.save()
            end
        elseif p.kind=="walls_ready" then
            local t,job=jobs.task(sender)
            local valid=t and t.id==p.taskId and job.kind=="walls" and job.closer==sender
            local ready=valid==true
            if valid then
                for id,other in pairs(job.tasks) do
                    if id~=sender and (other.status~="complete" or not other.progress or other.progress.completed~=other.total) then ready=false end
                end
            end
            self.send(sender,"walls_reply",{request=p.request,granted=ready,error=not valid and "invalid_wall_closer" or nil})
        elseif p.kind == "lock" then
            local w = state.workers[sender]
            local granted = false
            local reason
            if w and w.taskId == p.taskId and type(p.request) == "string" then
                local held=state.locks[p.resource]
                local _,job=jobs.task(sender)
                if type(p.resource)=="string" and p.resource:match("^wallgate:")
                    and (not job or job.kind~="walls" or p.resource~="wallgate:"..job.id) then
                    reason="unknown_resource"
                else granted,reason = model.acquire(state.locks, p.resource, sender, p.request) end
                if granted and not held then self.save() end
            end
            self.send(sender, "lock_reply", { request = p.request, granted = granted, resource = p.resource, error=reason })
        elseif p.kind == "release" then
            if model.release(state.locks, p.resource, sender, p.token) then self.save() end
            self.send(sender, "release_reply", { resource = p.resource, token = p.token })
        elseif p.kind=="reset_result" then
            local pending=state.pendingControls[sender]
            if not pending or pending.action~="reset" or pending.request~=p.request then return end
            local w,t=state.workers[sender],jobs.task(sender)
            if p.ok then
                if t and t.id==p.taskId then t.status,t.error="cancelled",nil end
                if w then
                    w.status,w.error,w.taskId,w.taskType="idle",nil,nil,nil
                    if w.packet then w.packet.progress=nil end
                end
            elseif w then w.controlError=p.error end
            state.pendingControls[sender]=nil
            self.save()
        elseif p.kind == "control_ack" then
            local pending = state.pendingControls[sender]
            if pending and pending.request == p.request and pending.action~="reset" then state.pendingControls[sender] = nil; self.save() end
        end
    end
    function self.control(action, target, jobId)
        local job=jobId and state.jobs[jobId]
        if jobId and not job then return false,"unknown_job" end
        local pending={}
        for id, w in pairs(state.workers) do
            if (not target or target==id) and (not job or (job.tasks[id] and job.tasks[id].id==w.taskId)) then
                state.serial = (state.serial or 0) + 1
                w.controlError=nil
                local packet = { action = action, taskId = w.taskId, request = "control:" .. state.serial, order = state.serial }
                state.pendingControls[id] = packet; pending[id]=packet
            end
        end
        if next(pending) then
            self.save()
            for id,packet in pairs(pending) do self.send(id,"control",store.copy(packet)) end
        end
        return true
    end
    function self.snapshot()
        local jobList,summary=jobs.snapshot()
        local workers = {}
        local tunnelOwners=model.tunnelOwners(state.locks)
        local serviceOwners=model.serviceOwners(state.locks)
        for id, w in pairs(state.workers) do
            local age = w.received == -1000000000 and 9999 or math.floor(os.clock() - w.received)
            local t,job=jobs.task(id)
            workers[id] = { packet = w.packet, label = w.label, status = age >= 6 and "offline" or w.status, age = age, error = w.controlError or w.error,
                jobId=job and job.id, jobNumber=job and job.number,
                taskType = t and t.id==w.taskId and (t.assignment.kind or "quarry") or w.taskType,
                taskTotal = t and t.id==w.taskId and t.total or nil,
                pendingControl = state.pendingControls[id] and state.pendingControls[id].action }
        end
        return { version = 1, kind = "fleet_snapshot", id = os.getComputerID(), workers = workers,
            jobs=jobList, summary = summary, serviceOwner = serviceOwners[1],serviceOwners=serviceOwners,
            tunnelOwner = tunnelOwners[1], tunnelOwners=tunnelOwners,
            message = "Ulohy: "..summary.jobs.." | Rozpracovane: "..summary.activeJobs }
    end
    function self.tick()
        local now = os.clock()
        if now - self.lastDiscover >= 3 then self.send(nil, "discover"); self.lastDiscover = now end
        if now - self.lastControl >= 1 then
            for id, pending in pairs(state.pendingControls) do self.send(id, "control", store.copy(pending)) end
            self.lastControl = now
        end
        if now - self.lastDispatch >= 5 then
            for _,job in pairs(state.jobs) do
                for id,t in pairs(job.tasks) do
                    if t.status=="assigned" and state.workers[id].taskId==t.id then self.send(id,"assign",{task=t.assignment}) end
                end
            end
            self.lastDispatch = now
        end
        if now - self.lastView >= 2 then
            if self.dirty then self.save() end
            rednet.broadcast(self.snapshot(), model.viewProtocol); self.lastView = now
        end
    end
    return self
end
return controller
