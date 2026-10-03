-- Fuel goals evaluated only when a service visit is already necessary.
local config = require("config")
local cuboid = require("cuboid")
local nav = require("navigation")
local telemetry = require("telemetry")
local budget = {}
function budget.new(kind, a, b)
    local box, err = cuboid.new(a, b)
    if not box then return nil, err end
    local last = cuboid.cell(box, box.volume, a)
    return function()
        local p, c, current = telemetry.getProgress(), config.load(), nav.getPosition()
        if not p or not c or not current or p.phase == "failed" or p.phase == "complete" then return 0 end
        local remaining = math.max(0, p.remaining or (box.volume - (p.completed or 0)))
        local function route(from, target)
            return math.max(nav.knownDistance(target, from) or 0, nav.estimateDistance(target, from))
        end
        local finish = { x = last.x, y = last.y, z = last.z }
        if kind == "floor" then finish.y = last.y + (current.y < a.y and -1 or 1) end
        local service = kind == "floor" and c.stations.materials or c.stations.output
        local capacity = math.max(1, 16 - #c.fuelSlots - 2) * 64
        if kind == "floor" then
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
            entryCost = route(current, first)
        end
        local fuelTrip = c.stations.fuel and 2 * route(current, c.stations.fuel) or 0
        return math.ceil(2 * (remaining + entryCost + returnCost + serviceCost + fuelTrip
            + c.navigation.reserve + 6 * c.navigation.maxDetour))
    end
end
return budget
