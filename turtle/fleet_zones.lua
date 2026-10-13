local dialog=require("fleet_dialog")
local area=require("work_area")
local zones={}
local function readFootprint(default)
    default=default or {min={},max={}}
    local function corner(label,p)
        print(label.." (iba X/Z)")
        return {x=dialog.number("X",p.x),z=dialog.number("Z",p.z)}
    end
    return assert(area.footprint(corner("Prvy roh podorysu",default.min),corner("Protilahly roh podorysu",default.max)))
end
function zones.prompt(c,kind)
    local saved=c.zones or {}
    local zone
    if dialog.yes("Pouzit preddefinovanu zonu? (nie = nova)",next(saved)~=nil) then
        if next(saved) then zone=saved[dialog.choose("Vyber pracovnu zonu",saved)]
        else print("Zatial nie su ulozene zony; zadaj novy podorys.") end
    end
    zone=zone or readFootprint()
    print("Podorys X="..zone.min.x..".."..zone.max.x..", Z="..zone.min.z..".."..zone.max.z)
    local first=dialog.number((kind=="floor" or kind=="ceiling") and "Y vrstvy blokov" or "Zaciatok vysky Y")
    local last=(kind=="floor" or kind=="ceiling") and first or dialog.number("Koniec vysky Y",first)
    return area.bounds(zone,first,last,kind,true)
end
function zones.edit(c)
    c.zones=c.zones or {}
    while true do
        print("PRACOVNE ZONY (podorysy bez vysky)")
        for _,name in ipairs(dialog.names(c.zones)) do
            local z=c.zones[name]
            print(name..": X "..z.min.x..".."..z.max.x..", Z "..z.min.z..".."..z.max.z)
        end
        print("1 Pridat | 2 Zmenit podorys | 3 Premenovat | 4 Odstranit | 0 Spat")
        local choice=dialog.number("Volba",0,0,4)
        if choice==0 then return end
        if choice==1 then
            local name=dialog.text("Nazov novej zony","")
            if name=="" or c.zones[name] then print("Nazov je prazdny alebo uz existuje.")
            else c.zones[name]=readFootprint() end
        elseif not next(c.zones) then print("Najprv pridaj zonu.")
        else
            local name=dialog.choose("Vyber zonu",c.zones)
            if choice==2 then c.zones[name]=readFootprint(c.zones[name])
            elseif choice==3 then
                local replacement=dialog.text("Novy nazov",name)
                if replacement~=name then
                    if replacement=="" or c.zones[replacement] then print("Nazov je prazdny alebo uz existuje.")
                    else c.zones[replacement],c.zones[name]=c.zones[name],nil end
                end
            elseif dialog.yes("Odstranit zonu "..name.."?",false) then c.zones[name]=nil end
        end
    end
end
return zones
