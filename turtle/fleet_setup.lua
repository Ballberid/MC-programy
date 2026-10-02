local settings = require("fleet_settings")
local dialog = require("fleet_dialog")
local c = settings.load()
while true do
    print("ZAKLADNA: 1 truhly, 2 predvolene truhly, 3 tunel/poschodia, 4 ulozit a skoncit")
    local choice = dialog.number("Volba", 4, 1, 4)
    if choice == 1 then
        dialog.names(c.stations)
        local name = dialog.text("Nazov novej alebo existujucej truhly")
        if name and name ~= "" then
            c.stations[name] = dialog.station()
        end
    elseif choice == 2 then
        if not next(c.stations) then print("Najprv pridaj truhly.")
        else
            for _, role in ipairs({ "fuel", "output", "materials" }) do
                c.defaults[role] = dialog.choose("Predvolena " .. role, c.stations, c.defaults[role], role == "materials")
            end
        end
    elseif choice == 3 then
        if dialog.yes("Pouzivat servisny tunel?", true) then
            c.tunnel = c.tunnel or { floors = {} }
            c.tunnel.x = dialog.number("X stredu prazdneho tunela 3x3", c.tunnel.x)
            c.tunnel.z = dialog.number("Z stredu prazdneho tunela 3x3", c.tunnel.z)
            repeat
                dialog.names(c.tunnel.floors)
                local name = dialog.text("Nazov poschodia (napr zakladna, prve)")
                if name and name ~= "" then
                    c.tunnel.floors[name] = { exit = dialog.point("Vystup mimo tunela: rovnake X alebo Z ako stred, aspon 2 bloky od stredu") }
                end
            until not dialog.yes("Pridat/upravit dalsie poschodie?", false)
        else c.tunnel = nil end
    else
        local ok, err = settings.save(c)
        if ok then print("Ulozene: data/fleet-settings.txt"); break end
        print("Neda sa ulozit: " .. tostring(err))
    end
end
