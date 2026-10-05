local settings = require("fleet_settings")
local dialog = require("fleet_dialog")
local c = settings.load()
while true do
    print("TRUHLY: 1 sprava truhiel | 2 predvolene truhly")
    print("PRESUNY: 3 tunel | 4 poschodia")
    print("0 ulozit a skoncit")
    local choice = dialog.number("Volba", 0, 0, 4)
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
            print("Tunel nastaveny. Poschodia spravuj samostatne vo volbe 4.")
            local valid, invalid = require("transit").validate(c.tunnel)
            if not valid then print("Pred ulozenim uprav poschodia: " .. tostring(invalid)) end
        else c.tunnel = nil end
    elseif choice == 4 then
        require("fleet_floors").edit(c)
    else
        local ok, err = settings.save(c)
        if ok then print("Ulozene: data/fleet-settings.txt"); break end
        print("Neda sa ulozit: " .. tostring(err))
    end
end
