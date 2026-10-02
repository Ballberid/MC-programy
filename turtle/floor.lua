-- Standalone rectangular floor builder; library use: building.run(a,b,block).
local dialog = require("fleet_dialog")
local building = require("building")
print("STAVANIE PODLAHY")
print("Rohy su BLOKY podlahy, oba maju rovnake Y.")
print("Turtle kladie zhora alebo zdola. Priprav truhlu materials cez setup.")
local a = dialog.point("Prvy roh podlahy", true)
local b = dialog.point("Protilahly roh podlahy", true)
local box, reason = building.validateArea(a, b)
if not box then error(reason, 0) end
local sample = turtle.getItemDetail(turtle.getSelectedSlot())
if sample then print("Vzorka vo vybranom slote: " .. sample.name) end
local name = dialog.text("ID bloku; Enter = vybrany slot alebo vzorka z truhly", "")
if name == "" then name = nil end
print("Plocha " .. box.size.x .. "x" .. box.size.z .. "; " .. box.volume .. " blokov. Turtle Y=" .. (a.y+1) .. " alebo " .. (a.y-1))
if not dialog.yes("Zacat stavanie?", false) then return end
local heading
if not dialog.yes("Zistit smer automaticky?", true) then
    heading = dialog.number("Smer: 0 sever, 1 vychod, 2 juh, 3 zapad", 0, 0, 3)
end
local function waitForMaterials(block, progress)
    print("Hotove " .. progress.completed .. "/" .. progress.total .. "; zostava " .. progress.remaining)
    print("Dopln materialovu truhlu blokom " .. block .. ".")
    print("1 - Truhla je doplnena, pokracovat")
    print("0 - Zrusit stavanie")
    return dialog.number("Volba", 0, 0, 1) == 1
end
local ok, err, progress = building.run(a, b, name, heading, nil, waitForMaterials)
if not ok then
    print(err == "cancelled_by_user" and "Stavanie zrusene." or ("Chyba: " .. tostring(err)))
    if progress then print("Hotove " .. progress.completed .. "/" .. progress.total .. "; navrat " .. tostring(progress.returnedHome)) end
end
