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
    -- Clock values from before reboot cannot represent current availability.
    for _, w in pairs(state.workers) do w.received = -1000000000 end
    local self = { state = state, settings = settings, lastView = -math.huge, lastDiscover = -math.huge, lastDispatch = -math.huge, lastControl = -math.huge }
    function self.save() store.save(path, state) end
    function self.send(id, kind, extra)
        local p = extra or {}; p.version, p.kind, p.id = 1, kind, os.getComputerID()
        if id then rednet.send(id, p, model.protocol) else rednet.broadcast(p, model.protocol) end
    end
    function self.available()
        local ids = {}
        for id, w in pairs(state.workers) do
            if os.clock() - w.received < 6 and (w.status == "idle" or w.status == "complete" or w.status == "failed") then ids[#ids+1] = id end
        end
        table.sort(ids); return ids
    end
    function self.start(a, b, ids, stations, tunnel, floor, options)
        options = options or {}
        local kind = options.kind or "quarry"
        if kind ~= "quarry" and kind ~= "floor" then return false, "invalid_task_kind" end
        if kind == "floor" then
            local valid, invalid = require("floor_plan").new(a, b)
            if not valid then return false, invalid end
        end
        for _, t in pairs(state.job and state.job.tasks or {}) do
            if t.status ~= "complete" and t.status ~= "failed" then return false, "previous_job_not_finished" end
        end
        if next(state.locks) then return false, "service_still_reserved" end
        local segments, err = model.split(a, b, #ids); if not segments then return false, err end
        local available, seen = {}, {}
        for _, id in ipairs(self.available()) do available[id] = true end
        state.serial = (state.serial or 0) + 1
        local jobId = tostring(os.getComputerID()) .. ":" .. tostring(os.epoch("utc")) .. ":" .. state.serial
        local area = assert(cuboid.new(a, b))
        local protected = kind == "floor" and require("floor_plan").protected(area) or area
        for id, w in pairs(state.workers) do
            if cuboid.contains(protected, w.dock) then return false, "dock_inside_area:" .. id end
        end
        local job = { id = jobId, kind = kind, total = area.volume, tasks = {} }
        for index, id in ipairs(ids) do
            if seen[id] or not available[id] then return false, "worker_unavailable:" .. tostring(id) end
            seen[id] = true
            local s = segments[index]
            local assignment = { id = jobId .. ":" .. index, jobId = jobId, a = s.a, b = s.b,
                area = area, stations = store.copy(stations), tunnel = store.copy(tunnel), floor = floor,
                kind = kind, block = options.block }
            local c, invalid = taskLib.settings(assignment, state.workers[id].dock)
            if not c then return false, invalid end
            job.tasks[id] = { id = assignment.id, total = s.total, status = "assigned", assignment = assignment }
        end
        state.job = job
        for id, t in pairs(job.tasks) do
            local w = state.workers[id]; w.status, w.taskId, w.error = "assigned", t.id, nil
            state.pendingControls[id] = nil
            w.packet = { activity = "assigned", message = "Cakam na potvrdenie", fuel = w.packet and w.packet.fuel,
                inventory = w.packet and w.packet.inventory, position = w.packet and w.packet.position }
        end
        self.save()
        for id, t in pairs(job.tasks) do self.send(id, "assign", { task = t.assignment }) end
        return true
    end
    function self.handle(sender, p, protocol)
        if type(p) ~= "table" or p.version ~= 1 or p.id ~= sender then return end
        if protocol == model.telemetryProtocol then
            local w = state.workers[sender]
            if not w or type(p.message) ~= "string" or #p.message > 4096 then return end
            local t = state.job and state.job.tasks[sender]
            if t and (type(p.context) ~= "table" or p.context.taskId ~= t.id) then return end
            if t then p.progress = model.updateProgress(t, p.progress) end
            w.packet, w.received = p, os.clock()
            return
        end
        if protocol ~= model.protocol then return end
        if p.kind == "status" then
            if type(p.status) ~= "string" or not require("config").isPoint(p.dock) then return end
            local count = 0; for _ in pairs(state.workers) do count = count + 1 end
            if not state.workers[sender] and count >= 32 then return end
            local w = state.workers[sender] or {}; state.workers[sender] = w
            local t = state.job and state.job.tasks[sender]
            if t and t.status ~= "complete" and t.status ~= "failed" and p.taskId ~= t.id then w.received = os.clock(); return end
            w.status, w.received, w.dock, w.label, w.error, w.taskId = p.status, os.clock(), p.dock, p.label, p.error, p.taskId
            w.packet = { activity = p.activity or p.status, level = p.error and "error" or "info", message = p.error or p.activity or p.status,
                label = p.label, fuel = p.fuel, inventory = p.inventory, position = p.position, progress = p.progress }
            if t and p.taskId == t.id then
                local changed = t.status ~= p.status
                t.status, t.error = p.status, p.error
                w.packet.progress = model.updateProgress(t, p.progress)
                if changed then self.save() end
            end
        elseif p.kind == "reject" then
            local t = state.job and state.job.tasks[sender]
            if t and t.id == p.taskId then
                t.status, t.error = "failed", p.error
                state.workers[sender].status, state.workers[sender].error = "recovery", p.error
                self.save()
            end
        elseif p.kind == "lock" then
            local w = state.workers[sender]
            local granted = false
            if w and w.taskId == p.taskId and type(p.request) == "string" then
                granted = model.acquire(state.locks, p.resource, sender, p.request)
                if granted then self.save() end
            end
            self.send(sender, "lock_reply", { request = p.request, granted = granted, resource = p.resource })
        elseif p.kind == "release" then
            if model.release(state.locks, p.resource, sender, p.token) then self.save() end
            self.send(sender, "release_reply", { resource = p.resource, token = p.token })
        elseif p.kind == "control_ack" then
            local pending = state.pendingControls[sender]
            if pending and pending.request == p.request then state.pendingControls[sender] = nil; self.save() end
        end
    end
    function self.control(action, target)
        for id, w in pairs(state.workers) do
            if not target or target == id then
                state.serial = (state.serial or 0) + 1
                local packet = { action = action, taskId = w.taskId, request = "control:" .. state.serial, order = state.serial }
                state.pendingControls[id] = packet; self.save()
                self.send(id, "control", store.copy(packet))
            end
        end
    end
    function self.snapshot()
        local workers = {}
        for id, w in pairs(state.workers) do
            local age = w.received == -1000000000 and 9999 or math.floor(os.clock() - w.received)
            workers[id] = { packet = w.packet, label = w.label, status = age >= 6 and "offline" or w.status, age = age, error = w.error,
                pendingControl = state.pendingControls[id] and state.pendingControls[id].action }
        end
        return { version = 1, kind = "fleet_snapshot", id = os.getComputerID(), workers = workers,
            summary = model.summary(state.job), serviceOwner = state.locks.service and state.locks.service.owner,
            tunnelOwner = state.locks.tunnel and state.locks.tunnel.owner,
            message = state.job and ("Uloha " .. state.job.id) or "Pripravene na novu ulohu" }
    end
    function self.tick()
        local now = os.clock()
        if now - self.lastDiscover >= 3 then self.send(nil, "discover"); self.lastDiscover = now end
        if now - self.lastControl >= 1 then
            for id, pending in pairs(state.pendingControls) do self.send(id, "control", store.copy(pending)) end
            self.lastControl = now
        end
        if now - self.lastDispatch >= 5 then
            for id, t in pairs(state.job and state.job.tasks or {}) do
                if t.status == "assigned" then self.send(id, "assign", { task = t.assignment }) end
            end
            self.lastDispatch = now
        end
        if now - self.lastView >= 2 then
            self.save()
            rednet.broadcast(self.snapshot(), model.viewProtocol); self.lastView = now
        end
    end
    return self
end
return controller
