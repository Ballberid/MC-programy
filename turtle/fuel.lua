local fuel = {}

function fuel.level()
    return turtle.getFuelLevel()
end

function fuel.has(amount)
    local level = fuel.level()
    return level == "unlimited" or level >= amount
end

function fuel.slots(settings)
    settings = settings or {}
    local slots, allowed = {}, settings.fuelSlots or {}
    for slot = 1, 16 do
        local included = #allowed == 0
        for _, value in ipairs(allowed) do if value == slot then included = true end end
        local item = turtle.getItemDetail(slot)
        if included and not (item and (settings.protectedItems or {})[item.name]) then slots[#slots + 1] = slot end
    end
    return slots
end

-- Consume only enough items to reach the requested level. No target = fill up.
function fuel.refuel(target, slots)
    local limit = turtle.getFuelLimit()
    if fuel.level() == "unlimited" then return "unlimited" end
    target = math.min(target or limit, limit)
    local selected = turtle.getSelectedSlot()
    if slots == nil then
        slots = {}
        for slot = 1, 16 do slots[#slots + 1] = slot end
    end
    for _, slot in ipairs(slots) do
        if fuel.has(target) then break end
        turtle.select(slot)
        while not fuel.has(target) and turtle.refuel(0) do
            if not turtle.refuel(1) then break end
        end
    end
    turtle.select(selected)
    return fuel.level()
end

function fuel.required(workMoves, returnMoves, reserve)
    return math.ceil(workMoves + returnMoves + (reserve or 20))
end

function fuel.ensure(amount, slots)
    if not fuel.has(amount) then fuel.refuel(amount, slots) end
    if fuel.has(amount) then return true end
    return false, "insufficient_fuel"
end

return fuel
