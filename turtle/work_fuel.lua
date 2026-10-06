-- Fuel goals evaluated only when a service visit is already necessary.
local config = require("config")
local cuboid = require("cuboid")
local nav = require("navigation")
local telemetry = require("telemetry")
local budget = {}
function budget.new(kind, a, b, options)
    local plan = kind == "walls" and require("wall_plan") or cuboid
    local box, err = plan.new(a, b, options)
    if not box then return nil, err end
    local last = (kind == "walls" and plan.cell or cuboid.cell)(box, box.volume, a)
    return function()
        local p, c, current = telemetry.getProgress(), config.load(), nav.getPosition()
        if not p or not c or not current or p.phase == "failed" or p.phase == "complete" then return 0 end
        local remaining = math.max(0, p.remaining or (box.volume - (p.completed or 0)))
        local function route(from, target)
            return math.max(nav.knownDistance(target, from) or 0, nav.estimateDistance(target, from))
        end
        local finish = { x = last.x, y = last.y, z = last.z }
        if kind == "floor" then finish.y = last.y + 1 end
        if kind == "ceiling" then finish.y = last.y - 1 end
        if kind == "walls" then finish=require("wall_access").new(box).stand(last) end
        local service = (kind == "floor" or kind == "ceiling" or kind == "walls") and c.stations.materials or c.stations.output
        local capacity = math.max(1, 16 - #c.fuelSlots - 2) * 64
        if kind == "floor" or kind == "ceiling" or kind == "walls" then
            capacity = 0
            local reserved = {}; for _, slot in ipairs(c.fuelSlots) do reserved[slot] = true end
            for slot = 1, 16 do
                local item = turtle.getItemDetail(slot)
                if not reserved[slot] and (not item or item.name == p.block) then
                    capacity = capacity + turtle.getItemSpace(slot) + (item and item.count or 0)
                end
            end
            capacity = math.max(1, capacity)
        end
        local extraVisits = remaining > 0 and math.max(0, math.ceil(remaining / capacity) - 1) or 0
        local serviceCost = service and 2 * extraVisits * math.max(route(current, service), route(finish, service)) or 0
        local returnCost = route(finish, c.home)
        if kind == "quarry" and service then returnCost = route(finish, service) + route(service, c.home) end
        local entryCost = 0
        if p.phase == "prepare" or p.phase == "entry" then
            local first = { x = a.x, y = a.y + (kind == "floor" and 1 or 0), z = a.z }
            if kind == "ceiling" then first.y=a.y-1 end
            if kind == "walls" then
                first=require("wall_access").new(box).stand(plan.cell(box,1,a))
                -- Enter through the service opening before reaching the inner wall face.
                if not box.includeCorners and not box.interiorAccess then
                    local gate={x=box.opening.x+(box.opening.x==box.min.x and -1 or 1),y=box.opening.y,z=box.opening.z}
                    entryCost=route(current,gate)+nav.distance(gate,first)
                end
            end
            if entryCost==0 then entryCost = route(current, first) end
        end
        local fuelTrip = c.stations.fuel and 2 * route(current, c.stations.fuel) or 0
        if kind == "walls" and c.stations.output then
            serviceCost=serviceCost+2*(1+extraVisits)*math.max(route(current,c.stations.output),route(finish,c.stations.output))
        end
        return math.ceil(2 * ((kind == "walls" and 3 or 1)*remaining + entryCost + returnCost + serviceCost + fuelTrip
            + c.navigation.reserve + 6 * c.navigation.maxDetour))
    end
end
return budget
