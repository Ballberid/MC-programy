local config = require("config")
local cuboid = require("cuboid")
local position = require("position")
local transit = require("transit")
local store = require("fleet_store")
local task = {}
function task.settings(job, dock, previous)
    if type(job) ~= "table" or type(job.id) ~= "string" or #job.id > 100
        or type(job.jobId) ~= "string" or type(job.stations) ~= "table" then return nil, "invalid_task" end
    local kind = job.kind or "quarry"
    if job.startDelay ~= nil and (type(job.startDelay) ~= "number" or job.startDelay ~= math.floor(job.startDelay)
        or job.startDelay < 0 or job.startDelay > 300) then return nil, "invalid_start_delay" end
    if job.startAfter~=nil and (type(job.startAfter)~="string" or #job.startAfter>100 or job.startAfter==job.id) then
        return nil,"invalid_start_predecessor"
    end
    if job.lane~=nil and job.lane~=1 and job.lane~=2 then return nil,"invalid_tunnel_lane" end
    if kind ~= "quarry" and kind ~= "floor" and kind ~= "ceiling" and kind ~= "walls" then return nil, "invalid_task_kind" end
    if kind ~= "quarry" and job.block ~= nil and (type(job.block) ~= "string" or not job.block:match("^[%w_%-]+:[%w_/%.-]+$")) then
        return nil, "invalid_block_name"
    end
    if kind=="walls" and (type(job.wallOptions)~="table" or type(job.wallOptions.segment)~="table") then return nil,"invalid_wall_segment" end
    local plan=kind=="walls" and require("wall_plan") or (kind=="ceiling" and require("ceiling_plan") or require("floor_plan"))
    local box, err = (kind ~= "quarry" and plan.new or cuboid.new)(job.a, job.b,job.wallOptions)
    if not box then return nil, err end
    local c = store.copy(previous or config.defaults())
    c.start, c.home, c.stations = store.copy(dock), store.copy(dock), store.copy(job.stations)
    c.telemetry = { enabled = true, protocol = "craftoria.turtle.v1", interval = 2 }
    local ok, reason = config.validate(c)
    if not ok then return nil, reason end
    if not c.stations.fuel or not c.stations.output then return nil, "fuel_output_required" end
    if kind ~= "quarry" and not c.stations.materials then return nil, "station_missing:materials" end
    local protected = job.area or box
    if type(protected) ~= "table" or not config.isPoint(protected.min) or not config.isPoint(protected.max) then return nil, "invalid_area" end
    if kind=="walls" then
        for _,axis in ipairs({"x","y","z"}) do
            if protected.min[axis]~=box.min[axis] or protected.max[axis]~=box.max[axis] then return nil,"wall_area_mismatch" end
        end
    end
    if kind == "floor" or kind == "ceiling" then
        if protected.min.y ~= protected.max.y then return nil, "floor_corners_need_same_y" end
        protected = require("floor_plan").protected(protected)
    end
    for _, s in pairs(c.stations) do
        if s.x == dock.x and s.y == dock.y and s.z == dock.z then return nil, "dock_at_shared_station" end
        if cuboid.contains(protected, position.offset(s, s.direction, s.side)) or cuboid.contains(protected, s) then
            return nil, "station_inside_area"
        end
    end
    if cuboid.contains(protected, dock) then return nil, "dock_inside_area" end
    local valid, invalid = transit.validate(job.tunnel)
    if not valid then return nil, invalid end
    if job.tunnel then
        if not job.floor or not job.tunnel.floors[job.floor] then return nil, "work_floor_missing" end
        local minimum, maximum
        for _, f in pairs(job.tunnel.floors) do
            local exitHits=kind=="walls" and require("wall_plan").isWall(protected,f.exit)
                or kind~="walls" and cuboid.contains(protected,f.exit)
            if exitHits then return nil, "floor_exit_inside_area" end
            local p = f.exit
            if p.y >= protected.min.y and p.y <= protected.max.y then
                local crossesX = p.z >= protected.min.z and p.z <= protected.max.z
                    and protected.min.x <= math.max(p.x, job.tunnel.x) and protected.max.x >= math.min(p.x, job.tunnel.x)
                local crossesZ = p.x >= protected.min.x and p.x <= protected.max.x
                    and protected.min.z <= math.max(p.z, job.tunnel.z) and protected.max.z >= math.min(p.z, job.tunnel.z)
                local crosses=crossesX or crossesZ
                if kind=="walls" then
                    crosses=require("wall_plan").intersects(protected,{min={x=math.min(p.x,job.tunnel.x),y=p.y,z=math.min(p.z,job.tunnel.z)},
                        max={x=math.max(p.x,job.tunnel.x),y=p.y,z=math.max(p.z,job.tunnel.z)}})
                end
                if crosses then return nil, "floor_corridor_inside_area" end
            end
            minimum = math.min(minimum or f.exit.y, f.exit.y)
            maximum = math.max(maximum or f.exit.y, f.exit.y)
        end
        local shaftHits=protected.min.x <= job.tunnel.x + 1 and protected.max.x >= job.tunnel.x - 1
            and protected.min.z <= job.tunnel.z + 1 and protected.max.z >= job.tunnel.z - 1
            and protected.min.y <= maximum and protected.max.y >= minimum
        if kind=="walls" then
            shaftHits=require("wall_plan").intersects(protected,{min={x=job.tunnel.x-1,y=minimum,z=job.tunnel.z-1},
                max={x=job.tunnel.x+1,y=maximum,z=job.tunnel.z+1}})
        end
        if shaftHits then return nil, "tunnel_inside_area" end
    end
    if kind=="walls" then
        -- An internal tunnel supplies permanent access: do not cut a second
        -- doorway through the wall or require exterior access to close it.
        local inside=job.tunnel and cuboid.contains(box,job.tunnel.floors[job.floor].exit) or false
        job.wallOptions.interiorAccess=inside; box.interiorAccess=inside
    end
    return c, nil, box
end
return task
