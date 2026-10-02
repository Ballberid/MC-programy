-- Standalone rectangular floor builder; library use: building.run(a,b,block).
local dialog = require("fleet_dialog")
local building = require("building")
print("STAVANIE PODLAHY")
print("Rohy su BLOKY podlahy, oba maju rovnake Y.")
print("Turtle sa pohybuje na Y+1. Priprav truhlu materials cez setup.")
local a = dialog.point("Prvy roh podlahy", true)
local b = dialog.point("Protilahly roh podlahy", true)
local box, reason = building.validateArea(a, b)
if not box then error(reason, 0) end
local name = dialog.text("ID bloku, napr. minecraft:stone; Enter = vzorka z truhly", "")
if name == "" then name = nil end
print("Plocha " .. box.size.x .. "x" .. box.size.z .. "; " .. box.volume .. " blokov. Turtle Y=" .. (a.y+1))
if not dialog.yes("Zacat stavanie?", false) then return end
local heading
if not dialog.yes("Zistit smer automaticky?", true) then
    heading = dialog.number("Smer: 0 sever, 1 vychod, 2 juh, 3 zapad", 0, 0, 3)
end
local ok, err, progress = building.run(a, b, name, heading)
if not ok then
    print("Chyba: " .. tostring(err))
    if progress then print("Hotove " .. progress.completed .. "/" .. progress.total .. "; navrat " .. tostring(progress.returnedHome)) end
end
