-- Background receiver; all request/reply handling uses this single listener.
local store = require("fleet_store")
local model = require("fleet_model")
local task = require("fleet_task")
local config = require("config")
local nav = require("navigation")
local telemetry = require("telemetry")
local inv = require("inventory")
local client = {}
local path = "data/worker-state.txt"

function client.new(controller, dock)
    local state = store.load(path, { version = 1, controller = controller, dock = dock, seen = {}, status = "idle" })
    if state.controller ~= controller then error("Turtle je sparovana s PC #" .. state.controller, 0) end
    state.seen = state.seen or {}
    state.lockTokens, state.pendingRelease = state.lockTokens or {}, state.pendingRelease or {}
    state.controlSeen = state.controlSeen or {}
    state.controlResults=state.controlResults or {}
    if state.task and state.status ~= "complete" and state.status ~= "failed" and state.status ~= "idle" then state.status = "recovery" end
    store.save(path, state)
    local self = { state = state, replies = {}, held = {}, serial = 0, paused = false, cancel = false, lastSaved = os.clock(), lastStatus = -math.huge }
    function self.save() store.save(path, state); self.lastSaved = os.clock() end
    function self.send(kind, extra)
        local packet = extra or {}; packet.kind, packet.version, packet.id = kind, 1, os.getComputerID()
        rednet.send(controller, packet, model.protocol)
    end
    function self.status(force)
        local now=os.clock()
        if not force and now-self.lastStatus<1 then return end
        self.lastStatus=now
        if state.status == "running" then
            state.progress = telemetry.getProgress() or state.progress
            if os.clock() - self.lastSaved >= 2 then self.save() end
        end
        for resource, token in pairs(state.pendingRelease) do self.send("release", { resource = resource, token = token }) end
        self.send("status", { status = self.paused and "paused" or state.status, taskId = state.task and state.task.id,
            taskType = state.task and (state.task.kind or "quarry"),
            jobId = state.task and state.task.jobId, label = os.getComputerLabel(), dock = state.dock,
            position = nav.getPosition(), fuel = turtle.getFuelLevel(), inventory = inv.snapshot(),
            progress = state.progress, error = state.error,
            activity = self.paused and "paused" or telemetry.getActivity() })
    end
    function self.checkpoint()
        while self.paused and not self.cancel do sleep(0.2) end
        if self.cancel then self.cancel = false; return false, "job_cancelled" end
        return true
    end
    function self.acquire(resource)
        if self.held[resource] then self.held[resource].depth = self.held[resource].depth + 1; return true end
        state.lockSerial = (state.lockSerial or 0) + 1
        local request = state.lockTokens[resource] or (tostring(os.getComputerID()) .. ":" .. state.lockSerial)
        state.lockTokens[resource] = request; self.save()
        local lastReply, last = os.clock(), -math.huge
        telemetry.setActivity("waiting:"..resource)
        while os.clock() - lastReply < 300 do
            local ok, err = self.checkpoint(); if not ok then return false, err end
            if os.clock() - last >= 2 and not state.pendingRelease[resource] then
                self.send("lock", { resource = resource, request = request, taskId = state.task and state.task.id })
                last = os.clock()
            end
            local reply = self.replies[request]
            if reply then
                lastReply=os.clock()
                self.replies[request] = nil
                if reply.granted then self.held[resource] = { depth = 1, token = request }; return true end
                if reply.error and reply.error~="occupied" then return false,reply.error end
            end
            sleep(0.1)
        end
        return false, "controller_unreachable:"..resource
    end
    function self.release(resource)
        local held = self.held[resource]
        if not held then return end
        if held.depth > 1 then held.depth = held.depth - 1; return end
        self.held[resource] = nil
        state.lockTokens[resource] = nil
        state.pendingRelease[resource] = held.token; self.save()
        self.send("release", { resource = resource, token = held.token })
    end
    function self.clearClaims()
        -- Only release this worker's tokens. Never clear another owner's lock.
        for resource,token in pairs(state.lockTokens) do
            state.pendingRelease[resource]=token
            self.send("release",{resource=resource,token=token})
        end
        self.held,state.lockTokens={},{}
    end
    function self.reset()
        if self.queued or state.status=="running" or state.status=="assigned" then return false,"reset_requires_stop" end
        local synced,err=nav.sync(); if not synced then return false,err end
        if nav.distance(nav.getPosition(),state.dock)~=0 then return false,"reset_requires_dock" end
        if state.previous then
            local restored,reason=config.save(state.previous); if not restored then return false,reason end
        end
        self.clearClaims()
        self.paused,self.cancel,self.recovery,self.retry=false,false,false,false
        state.task,state.progress,state.error,state.previous=nil,nil,nil,nil
        state.status="idle"; telemetry.setProgress(nil); telemetry.setActivity("idle"); self.save()
        return true
    end
    function self.handle(sender, packet)
        if sender ~= controller or type(packet) ~= "table" or packet.version ~= 1 then return end
        if packet.kind == "discover" then self.status()
        elseif packet.kind == "lock_reply" and type(packet.request) == "string" then
            self.replies[packet.request] = packet
        elseif packet.kind == "release_reply" and type(packet.resource) == "string" and type(packet.token) == "string"
            and state.pendingRelease[packet.resource] == packet.token then
            state.pendingRelease[packet.resource] = nil; self.save()
        elseif packet.kind == "assign" then
            local job = packet.task
            if type(job) ~= "table" or type(job.id) ~= "string" then return end
            if state.seen[job.id] or (state.task and state.task.id == job.id) then self.status(); return end
            if state.status ~= "idle" and state.status ~= "complete" and state.status ~= "failed" then
                self.send("reject", { taskId = job.id, error = "worker_busy" }); return
            end
            local c, err = task.settings(job, state.dock, config.load())
            if not c then self.send("reject", { taskId = job.id, error = err }); return end
            state.task, state.status, state.progress, state.error = job, "assigned", nil, nil
            telemetry.setProgress(nil)
            state.previous = config.load()
            state.seen[job.id] = true
            self.queued, self.recovery, self.retry = true, false, false
            self.save(); self.status(true)
        elseif packet.kind == "control" then
            if (packet.request and state.controlSeen[packet.request])
                or (type(packet.order) == "number" and packet.order <= (state.lastControl or 0)) then
                if packet.request and state.controlResults[packet.request] then
                    self.send("reset_result",store.copy(state.controlResults[packet.request]))
                end
                self.send("control_ack", { request = packet.request }); return
            end
            if packet.taskId and (not state.task or state.task.id~=packet.taskId) then return end
            if packet.action=="reset" then
                local taskId=state.task and state.task.id
                local ok,reason=self.reset()
                local result={request=packet.request,taskId=taskId,ok=ok,error=reason}
                if packet.request then state.controlResults[packet.request]=store.copy(result) end
                self.send("reset_result",result)
            elseif state.status == "recovery" and packet.action == "stop" then
                self.queued, self.recovery, self.retry = true, true, false
            elseif (state.status == "recovery" or state.status == "failed") and packet.action == "resume" and state.task then
                if nav.getPosition() and nav.sync() and nav.distance(nav.getPosition(),state.dock)==0 then self.clearClaims() end
                self.queued, self.recovery, self.retry = true, false, true
                self.paused, self.cancel = false, false
                state.status, state.error = "assigned", nil
                self.save()
            elseif state.status == "running" or state.status == "assigned" then
                if packet.action == "pause" then self.paused = true
                elseif packet.action == "resume" then self.paused = false
                elseif packet.action == "stop" then self.cancel, self.paused = true, false end
            end
            if type(packet.order) == "number" then state.lastControl = packet.order end
            if packet.request then state.controlSeen[packet.request] = true; self.save() end
            self.send("control_ack", { request = packet.request })
            self.status(true)
        end
    end
    function self.finish(ok, err, progress)
        state.status, state.error, state.progress = ok and "complete" or "failed", err, progress
        self.paused, self.cancel = false, false
        self.save(); self.status(true)
    end
    return self
end
return client
