-- All answers start on a separate line, including small computer terminals.
local dialog = {}
function dialog.text(prompt, default)
    print(prompt .. (default ~= nil and " [" .. tostring(default) .. "]" or ""))
    write("> ")
    local value = read():match("^%s*(.-)%s*$")
    return value == "" and default or value
end
function dialog.number(prompt, default, minimum, maximum)
    while true do
        local value = tonumber(dialog.text(prompt, default))
        if value and value % 1 == 0 and value >= (minimum or -30000000) and value <= (maximum or 30000000) then return value end
        print("Zadaj cele cislo v povolenom rozsahu.")
    end
end
function dialog.point(prompt, block, default)
    print(prompt .. (block and " (suradnice bloku)" or " (pozicia turtle, nie bloku truhly)"))
    default = default or {}
    return { x = dialog.number("X", default.x), y = dialog.number("Y", default.y), z = dialog.number("Z", default.z) }
end
function dialog.yes(prompt, default)
    while true do
        local value = tostring(dialog.text(prompt .. (default and " [A/n]" or " [a/N]"), "")):lower()
        if value == "" then return default end
        if value == "a" or value == "y" or value == "ano" or value == "yes" then return true end
        if value == "n" or value == "nie" or value == "no" then return false end
        print("Pouzi a/y alebo n; Enter zvoli velke pismeno.")
    end
end
function dialog.names(map)
    local names = {}; for name in pairs(map) do names[#names+1] = name end; table.sort(names)
    for i, name in ipairs(names) do print(i .. ": " .. name) end
    return names
end
function dialog.choose(prompt, map, default, optional)
    local names = dialog.names(map)
    while true do
        local answer = dialog.text(prompt .. (optional and " (- = ziadna)" or ""), default)
        if optional and (answer == "-" or answer == nil) then return nil end
        local name = names[tonumber(answer)] or answer
        if name and map[name] then return name end
        print("Vyber cislo alebo nazov zo zoznamu.")
    end
end
function dialog.station()
    local s = dialog.point("Miesto pred truhlou")
    s.direction = dialog.number("Smer: 0 sever -Z, 1 vychod +X, 2 juh +Z, 3 zapad -X", 0, 0, 3)
    repeat s.side = dialog.text("Truhla: front / up / down", "front") until s.side == "front" or s.side == "up" or s.side == "down"
    return s
end
return dialog
