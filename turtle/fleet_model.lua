-- Pure scheduling and totals. A missing worker is never reassigned automatically.
local cuboid = require("cuboid")
local model = {}
model.protocol = "craftoria.fleet.v1"
model.viewProtocol = "craftoria.fleet.view.v1"
model.telemetryProtocol = "craftoria.turtle.v1"

function model.split(a, b, count)
    local box, err = cuboid.new(a, b)
    if not box then return nil, err end
    if type(count) ~= "number" or count < 1 or count % 1 ~= 0 or count > 32 then return nil, "invalid_worker_count" end
    local axis = box.size.x >= box.size.z and "x" or "z"
    if count > box.size[axis] then return nil, "too_many_workers_for_area" end
    local segments, offset = {}, 0
    for i = 1, count do
        local size = math.floor(box.size[axis] / count) + (i <= box.size[axis] % count and 1 or 0)
        local first, last = {}, {}
        for _, key in ipairs({ "x", "y", "z" }) do first[key], last[key] = a[key], b[key] end
        local sign = a[axis] <= b[axis] and 1 or -1
        first[axis], last[axis] = a[axis] + sign * offset, a[axis] + sign * (offset + size - 1)
        local part = assert(cuboid.new(first, last))
        segments[i] = { a = first, b = last, total = part.volume }
        offset = offset + size
    end
    return segments
end

function model.summary(job)
    local summary = { total = job and job.total or 0, completed = 0, dug = 0, active = 0, failed = 0,
        kind = job and job.kind or "quarry", placed = 0, skipped = 0 }
    for _, task in pairs(job and job.tasks or {}) do
        local p = task.progress or {}
        summary.completed = summary.completed + math.max(0, math.min(task.total, tonumber(p.completed) or 0))
        summary.dug = summary.dug + math.max(0, tonumber(p.dug) or 0)
        summary.placed = summary.placed + math.max(0, tonumber(p.placed) or 0)
        summary.skipped = summary.skipped + math.max(0, tonumber(p.skipped) or 0)
        if task.status == "failed" or task.status == "recovery" then summary.failed = summary.failed + 1
        elseif task.status ~= "complete" and task.status~="cancelled" then summary.active = summary.active + 1 end
    end
    summary.remaining = summary.total - summary.completed
    return summary
end

function model.updateProgress(task, progress)
    if type(progress) ~= "table" then return task.progress end
    local old = task.progress or {}
    local completed = math.max(tonumber(old.completed) or 0, tonumber(progress.completed) or 0)
    completed = math.max(0, math.min(task.total, completed))
    task.progress = { total = task.total, completed = completed, remaining = task.total - completed,
        dug = math.max(tonumber(old.dug) or 0, tonumber(progress.dug) or 0), phase = progress.phase or old.phase,
        placed = math.max(tonumber(old.placed) or 0, tonumber(progress.placed) or 0),
        skipped = math.max(tonumber(old.skipped) or 0, tonumber(progress.skipped) or 0),
        taskType = progress.taskType or old.taskType, block = progress.block or old.block }
    return task.progress
end

-- Locks survive coordinator restarts. No timer may release an offline owner.
function model.acquire(locks, resource, owner, token)
    local traffic=type(resource)=="string" and (resource=="tunnel:up:1" or resource=="tunnel:up:2"
        or resource=="tunnel:down" or resource:match("^door:%-?%d+,%-?%d+,%-?%d+$"))
    local station=type(resource)=="string" and resource:match("^station:%-?%d+,%-?%d+,%-?%d+$")
    if resource ~= "service" and resource ~= "tunnel" and not traffic and not station then return false, "unknown_resource" end
    if station and locks.service and locks.service.owner~=owner then return false,"occupied" end
    -- An old exclusive reservation cannot be bypassed during migration.
    if traffic and locks.tunnel and locks.tunnel.owner~=owner then return false,"occupied" end
    if resource=="tunnel" then
        for name,entry in pairs(locks) do
            if (name:match("^tunnel:") or name:match("^door:")) and entry.owner~=owner then return false,"occupied" end
        end
    end
    local held = locks[resource]
    if held and (held.owner ~= owner or held.token ~= token) then return false, "occupied" end
    locks[resource] = { owner = owner, token = token }
    return true
end
function model.tunnelOwners(locks)
    local owners,seen={},{}
    for name,entry in pairs(locks) do
        if (name=="tunnel" or name:match("^tunnel:") or name:match("^door:")) and not seen[entry.owner] then
            seen[entry.owner]=true; owners[#owners+1]=entry.owner
        end
    end
    table.sort(owners); return owners
end
function model.serviceOwners(locks)
    local owners,seen={},{}
    for name,entry in pairs(locks) do
        if (name=="service" or name:match("^station:")) and not seen[entry.owner] then
            seen[entry.owner]=true; owners[#owners+1]=entry.owner
        end
    end
    table.sort(owners); return owners
end
function model.release(locks, resource, owner, token)
    local held = locks[resource]
    if not held or held.owner ~= owner or held.token ~= token then return false end
    locks[resource] = nil
    return true
end
return model
