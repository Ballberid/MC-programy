-- build menu entry; standalone command: walls.
local dialog=require("fleet_dialog")
local building=require("building")
print("STAVANIE STIEN MIESTNOSTI")
print("Rohy su BLOKY kvadra. Stavia iba styri bocne steny.")
print("Podlaha, strop a vnutro sa nemenia. Steny kladie pred seba zvnutra.")
print("Rohy su volitelne. Docasny priechod uzavrie az po vyjdeni von.")
print("Priprav truhly fuel, materials a output cez setup.")
local a=dialog.point("Prvy roh kvadra",true)
local b=dialog.point("Protilahly roh kvadra",true)
print("Pri volbe ano treba pristup zvonka k rohom.")
local options={includeCorners=dialog.yes("Spravit aj rohy?",false)}
print(options.includeCorners and "Rohy dokonci zvonka." or "Bez rohov: steny stavia iba zvnutra, rohove stlpce nemeni.")
local box,reason=building.validateArea(a,b,"walls",options)
if not box then error(reason,0) end
local sample=turtle.getItemDetail(turtle.getSelectedSlot())
if sample then print("Vzorka vo vybranom slote: "..sample.name) end
local name=dialog.text("ID bloku; Enter = vybrany slot alebo vzorka z truhly","")
if name=="" then name=nil end
print("Rozmery "..box.size.x.."x"..box.size.y.."x"..box.size.z.."; steny "..box.volume.." blokov.")
print("Docasny priechod: "..box.opening.x..","..box.opening.y..","..box.opening.z.." (uzavrie na konci).")
print("Existujuce ine bloky na stenach sa vykopu a nahradia!")
if not dialog.yes("Zacat stavanie?",false) then return end
local heading
if not dialog.yes("Zistit smer automaticky?",true) then
    heading=dialog.number("Smer: 0 sever, 1 vychod, 2 juh, 3 zapad",0,0,3)
end
local function waitForMaterials(block,p)
    print("Hotove "..p.completed.."/"..p.total.."; zostava "..p.remaining)
    print("Dopln materialovu truhlu blokom "..block..".")
    print("1 - Truhla je doplnena, pokracovat; 0 - Zrusit stavanie")
    return dialog.number("Volba",0,0,1)==1
end
local ok,err,p=building.runWalls(a,b,name,heading,waitForMaterials,options)
if not ok then
    print(err=="cancelled_by_user" and "Stavanie zrusene." or ("Chyba: "..tostring(err)))
    if p then print("Hotove "..p.completed.."/"..p.total.."; navrat "..tostring(p.returnedHome)) end
end
