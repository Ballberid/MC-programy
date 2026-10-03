local settings = require("fleet_settings")
local dialog = require("fleet_dialog")
local c = settings.load()
while true do
    print("ZAKLADNA: 1 truhly, 2 predvolene truhly, 3 tunel, 4 ulozit a skoncit, 5 poschodia")
    local choice = dialog.number("Volba", 4, 1, 5)
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
            print("Tunel nastaveny. Poschodia spravuj samostatne vo volbe 5.")
            local valid, invalid = require("transit").validate(c.tunnel)
            if not valid then print("Pred ulozenim uprav poschodia: " .. tostring(invalid)) end
        else c.tunnel = nil end
    elseif choice == 5 then
        require("fleet_floors").edit(c)
    else
        local ok, err = settings.save(c)
        if ok then print("Ulozene: data/fleet-settings.txt"); break end
        print("Neda sa ulozit: " .. tostring(err))
    end
end
