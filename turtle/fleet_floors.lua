-- Manage exits independently of the shaft's fixed X/Z coordinates.
local transit = require("transit")
local dialog = require("fleet_dialog")
local floors = {}
local function validName(name)
    return type(name) == "string" and name ~= ""
end
local function validateExit(tunnel, name, exit)
    local ok, err = transit.validate({ x = tunnel.x, z = tunnel.z, floors = { [name] = { exit = exit } } })
    if not ok then return false, err end
    for other, floor in pairs(tunnel.floors) do
        if other ~= name and floor.exit.y == exit.y then return false, "duplicate_floor_height" end
    end
    return true
end
function floors.add(tunnel, name, exit)
    if not validName(name) then return false, "invalid_floor_name" end
    if tunnel.floors[name] then return false, "floor_name_exists" end
    local ok, err = validateExit(tunnel, name, exit)
    if not ok then return false, err end
    tunnel.floors[name] = { exit = { x = exit.x, y = exit.y, z = exit.z } }
    return true
end
function floors.rename(tunnel, name, replacement)
    if not tunnel.floors[name] then return false, "unknown_floor" end
    if not validName(replacement) then return false, "invalid_floor_name" end
    if replacement == name then return true end
    if tunnel.floors[replacement] then return false, "floor_name_exists" end
    tunnel.floors[replacement], tunnel.floors[name] = tunnel.floors[name], nil
    return true
end
function floors.setExit(tunnel, name, exit)
    if not tunnel.floors[name] then return false, "unknown_floor" end
    local ok, err = validateExit(tunnel, name, exit)
    if not ok then return false, err end
    tunnel.floors[name].exit = { x = exit.x, y = exit.y, z = exit.z }
    return true
end
function floors.remove(tunnel, name)
    if not tunnel.floors[name] then return false, "unknown_floor" end
    local count = 0; for _ in pairs(tunnel.floors) do count = count + 1 end
    if count == 1 then return false, "last_floor_required" end
    tunnel.floors[name] = nil
    return true
end
local messages = {
    floor_name_exists = "Tento nazov uz existuje; vyber iny.",
    invalid_floor_name = "Nazov nesmie byt prazdny.",
    duplicate_floor_height = "Na tomto Y uz mas ine poschodie.",
    exit_must_align_with_shaft = "Vystup musi mat rovnake X alebo Z ako stred a byt aspon 2 bloky od stredu.",
    last_floor_required = "Posledne poschodie nemozes odstranit. Pridaj ine alebo vypni tunel vo volbe 3.",
}
function floors.edit(c)
    if not c.tunnel then print("Najprv nastav tunel vo volbe 3."); return end
    local t = c.tunnel
    while true do
        print("POSCHODIA; tunel X=" .. t.x .. ", Z=" .. t.z)
        local names = {}; for name in pairs(t.floors) do names[#names+1] = name end; table.sort(names)
        for i, name in ipairs(names) do
            local p = t.floors[name].exit
            print(i .. ": " .. name .. " -> " .. p.x .. "," .. p.y .. "," .. p.z)
        end
        print("1 Pridat | 2 Premenovat | 3 Zmenit vystup | 4 Odstranit | 0 Spat")
        local choice = dialog.number("Volba", 0, 0, 4)
        if choice == 0 then return end
        local ok, err
        if choice == 1 then
            local name = dialog.text("Nazov noveho poschodia", "")
            if not validName(name) or t.floors[name] then
                ok, err = false, validName(name) and "floor_name_exists" or "invalid_floor_name"
            else
                ok, err = floors.add(t, name, dialog.point("Vystup: pozicia turtle mimo tunela"))
            end
        elseif not next(t.floors) then print("Najprv pridaj poschodie.")
        else
            local name = dialog.choose("Vyber poschodie", t.floors)
            if choice == 2 then
                ok, err = floors.rename(t, name, dialog.text("Novy nazov", name))
            elseif choice == 3 then
                ok, err = floors.setExit(t, name, dialog.point("Novy vystup; Enter ponecha suradnicu", false, t.floors[name].exit))
            elseif dialog.yes("Odstranit poschodie " .. name .. "?", false) then
                ok, err = floors.remove(t, name)
            end
        end
        if ok then print("Upravene. Zmeny uloz vo volbe 0 hlavneho menu.")
        elseif err then print(messages[err] or ("Neda sa upravit: " .. tostring(err))) end
    end
end
return floors
