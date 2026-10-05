local inv = {}

function inv.freeSlotList()
    local slots = {}
    for slot = 1, 16 do
        if turtle.getItemCount(slot) == 0 then slots[#slots + 1] = slot end
    end
    return slots
end

function inv.freeSlots()
    return #inv.freeSlotList()
end

-- Check fresh counts, but stop as soon as the required space is found.
function inv.hasFreeSlots(amount)
    if amount <= 0 then return true end
    for slot = 1, 16 do
        if turtle.getItemCount(slot) == 0 then
            amount = amount - 1
            if amount <= 0 then return true end
        end
    end
    return false
end

function inv.count(name)
    local count = 0
    for slot = 1, 16 do
        local item = turtle.getItemDetail(slot)
        if item and item.name == name then count = count + item.count end
    end
    return count
end

function inv.find(name)
    for slot = 1, 16 do
        local item = turtle.getItemDetail(slot)
        if item and item.name == name then return slot end
    end
    return nil, "item_missing"
end

function inv.select(name)
    local selected = turtle.getSelectedSlot()
    local item = turtle.getItemDetail(selected)
    if item and item.name == name then return true end
    local slot, err = inv.find(name)
    if not slot then return false, err end
    return turtle.select(slot)
end

-- Matching names estimate capacity; NBT variants may not stack together.
function inv.space(name)
    local space = 0
    for slot = 1, 16 do
        local item = turtle.getItemDetail(slot)
        if not item or item.name == name then space = space + turtle.getItemSpace(slot) end
    end
    return space
end

function inv.snapshot()
    local items = {}
    for slot = 1, 16 do
        local item = turtle.getItemDetail(slot)
        if item then items[#items + 1] = { slot = slot, name = item.name, count = item.count } end
    end
    return { freeSlots = 16 - #items, items = items }
end

function inv.hasMaterials(materials)
    for name, amount in pairs(materials or {}) do
        if inv.count(name) < amount then return false, name end
    end
    return true
end

return inv
