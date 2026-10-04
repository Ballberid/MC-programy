-- One renderer for the controller monitor and the pocket's paged view.
local display = {}
function display.ids(snapshot)
    local ids = {}; for id in pairs(snapshot.workers or {}) do ids[#ids+1] = id end
    table.sort(ids); return ids
end
function display.draw(screen, snapshot, selection, wide)
    local width, height = screen.getSize()
    screen.clear()
    local row = 1
    local function out(value, wrap)
        local text = tostring(value or "?"):gsub("[%c]", " "):sub(1, 200)
        repeat
            if row > height - 1 then return end
            screen.setCursorPos(1, row); screen.write(text:sub(1, width)); row = row + 1
            text = text:sub(width+1)
        until wrap == false or #text == 0
    end
    local ids = display.ids(snapshot)
    selection = math.max(0, math.min(selection or 0, #ids))
    out("Craftoria", false)
    out(snapshot.message or "Cakam na telemetriu...", false)
    if selection == 0 then
        local s = snapshot.summary or {}
        out("Hotove: " .. (s.completed or 0) .. "/" .. (s.total or 0))
        out("Zostava: " .. (s.remaining or 0))
        if s.kind == "floor" then out("Polozene: " .. (s.placed or 0) .. " Ex.: " .. (s.skipped or 0)) end
        out("Ulohy: " .. (s.active or 0) .. " Problemy: " .. (s.failed or 0))
        out("Turtle: " .. #ids .. "  Servis: " .. tostring(snapshot.serviceOwner or "volny"))
        out("Tunel: " .. (snapshot.tunnelOwners and #snapshot.tunnelOwners>0 and table.concat(snapshot.tunnelOwners,",") or tostring(snapshot.tunnelOwner or "volny")))
        if wide and width >= 60 then
            out("ID    STAV          PALIVO   SLOTY  HOTOVE/CELKOM", false)
            for _, id in ipairs(ids) do
                local w = snapshot.workers[id]; local p = w.packet or {}
                local progress = type(p.progress) == "table" and p.progress or {}
                local inventory = type(p.inventory) == "table" and p.inventory or {}
                out(string.format("%-5s %-13s %-8s %-6s %s/%s", tostring(id), tostring(w.status or p.activity or "?"),
                    tostring(p.fuel or "?"), tostring(inventory.freeSlots or "?"),
                    tostring(progress.completed or 0), tostring(progress.total or 0)), false)
                if w.error then out("  ! " .. w.error, false) end
            end
        else
            for _, id in ipairs(ids) do
                local w = snapshot.workers[id]
                out("#" .. id .. " " .. tostring(w.status or "?") .. " " .. tostring(w.age or 0) .. "s", false)
            end
        end
    else
        local id = ids[selection]; local w = snapshot.workers[id]; local p = w.packet or {}
        out("#" .. id .. " " .. tostring(p.label or w.label or "") .. " (" .. tostring(w.age or 0) .. "s)", false)
        out("Palivo: " .. tostring(p.fuel or "?"))
        local inventory = type(p.inventory) == "table" and p.inventory or {}
        out("Volne sloty: " .. tostring(inventory.freeSlots or "?"))
        local progress = p.progress
        if type(progress) == "table" and type(progress.completed) == "number" and type(progress.total) == "number"
            and type(progress.remaining) == "number" then
            out("Hotove: " .. progress.completed .. "/" .. progress.total)
            out("Zostava: " .. progress.remaining)
            if progress.taskType == "floor" then
                out("Polozene: " .. tostring(progress.placed or 0))
                out("Existujuce: " .. tostring(progress.skipped or 0))
            else out("Rozbite bloky: " .. tostring(progress.dug or 0)) end
        end
        out("Stav: " .. tostring(p.activity or w.status or "?") .. " | " .. tostring(p.level or "info"))
        if w.pendingControl then out("Caka povel: " .. w.pendingControl) end
        local pos = p.position
        if type(pos) == "table" then
            out("XYZ: " .. tostring(pos.x) .. "," .. tostring(pos.y) .. "," .. tostring(pos.z) .. " dir=" .. tostring(pos.direction))
        end
        out(w.error or p.message)
    end
    screen.setCursorPos(1, height)
    screen.write((selection == 0 and "0 prehlad | sipky detail" or (selection .. "/" .. #ids .. " sipky | 0 prehlad")):sub(1, width))
    return selection
end
return display
