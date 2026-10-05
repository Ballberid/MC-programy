-- Shared dialog for one-block-thick floors and ceilings.
local dialog = require("fleet_dialog")
local building = require("building")
local program={}
function program.run(kind)
    local ceiling=kind=="ceiling"
    local label=ceiling and "stropu" or "podlahy"
    print(ceiling and "STAVANIE STROPU" or "STAVANIE PODLAHY")
    print("Rohy su BLOKY " .. label .. ". Y zadas iba pre prvy roh.")
    print(ceiling and "Turtle kladie iba nad seba." or "Turtle kladie iba pod seba.")
    print("Priprav truhlu materials cez setup.")
    local a = dialog.point("Prvy roh " .. label, true)
    local b = dialog.flatPoint("Protilahly roh " .. label, a.y)
    local box, reason = building.validateArea(a, b, kind)
    if not box then error(reason, 0) end
    local sample = turtle.getItemDetail(turtle.getSelectedSlot())
    if sample then print("Vzorka vo vybranom slote: " .. sample.name) end
    local name = dialog.text("ID bloku; Enter = vybrany slot alebo vzorka z truhly", "")
    if name == "" then name = nil end
    print("Plocha " .. box.size.x .. "x" .. box.size.z .. "; " .. box.volume .. " blokov. Turtle Y=" .. (a.y + (ceiling and -1 or 1)))
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
    local ok, err, progress = (ceiling and building.runCeiling or building.run)(a, b, name, heading, nil, waitForMaterials)
    if not ok then
        print(err == "cancelled_by_user" and "Stavanie zrusene." or ("Chyba: " .. tostring(err)))
        if progress then print("Hotove " .. progress.completed .. "/" .. progress.total .. "; navrat " .. tostring(progress.returnedHome)) end
    end
end
return program
