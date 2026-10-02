-- Controller: interactive dialogs stay on the PC; monitor shows live data.
local network = require("network")
local settings = require("fleet_settings")
local dialog = require("fleet_dialog")
local display = require("fleet_display")
local config = require("config")
local model = require("fleet_model")
local store = require("fleet_store")
local opened, err = network.open(); if not opened then error("Pripoj modem: " .. tostring(err), 0) end
local control = require("fleet_controller").new(settings.load())
local monitor = peripheral.find("monitor")
if monitor then monitor.setTextScale(0.5) end
local function pickStations(c, kind)
    local stations = {}
    for _, role in ipairs({ "fuel", "output", "materials" }) do
        print("Stanica: " .. role .. " (fuel=palivo, output=vykladanie, materials=material)")
        if dialog.yes("Docasna truhla iba pre tuto ulohu?", false) then stations[role] = dialog.station()
        else
            local optional = role == "materials" and kind ~= "floor"
            if not next(c.stations) and not optional then print("Pridaj truhly cez fleet_setup."); return nil end
            local name = dialog.choose("Vyber " .. role, c.stations, c.defaults[role], optional)
            if name then stations[role] = store.copy(c.stations[name]) end
        end
    end
    return stations
end
local function newJob(kind)
    kind = kind or "quarry"
    local ids = control.available()
    if #ids == 0 then print("Ziadna pripravena turtle. Spusti worker ID_PC."); return end
    print("Dostupne ID: " .. table.concat(ids, ", "))
    local count = dialog.number("Kolko turtle pouzit?", #ids, 1, #ids)
    local selected = {}
    if dialog.yes("Vybrat konkretne ID?", false) then
        local available, seen = {}, {}; for _, id in ipairs(ids) do available[id] = true end
        for i = 1, count do
            repeat
                selected[i] = dialog.number("ID turtle " .. i, nil, 0)
            until available[selected[i]] and not seen[selected[i]]
            seen[selected[i]] = true
        end
    else for i = 1, count do selected[i] = ids[i] end end
    if kind == "floor" then print("Rohy su bloky podlahy s rovnakym Y; turtle chodi na Y+1.") end
    local a = dialog.point("Prvy roh oblasti", true)
    local b = dialog.point("Protilahly roh oblasti", true)
    local block
    if kind == "floor" then
        local valid, invalid = require("floor_plan").new(a, b)
        if not valid then print(invalid); return end
        block = dialog.text("ID bloku; Enter = vzorka z materialovej truhly", "")
        if block == "" then block = nil end
    end
    local c = settings.load(); control.settings = c
    local stations = pickStations(c, kind); if not stations then return end
    local floor
    if c.tunnel then floor = dialog.choose("Pracovne poschodie", c.tunnel.floors) end
    local parts, reason = model.split(a, b, count)
    if not parts then print(reason); return end
    for i, part in ipairs(parts) do print("#" .. selected[i] .. ": " .. part.total .. " miest") end
    if not dialog.yes(kind == "floor" and "Spustit stavanie podlahy?" or "Spustit spolocny vykop?", false) then return end
    local started, startErr = control.start(a, b, selected, stations, c.tunnel, floor, { kind = kind, block = block })
    print(started and "Ulohy odoslane. Potvrdenia sleduj na monitore." or ("Nespustene: " .. tostring(startErr)))
end
local function input()
    print("RIADIACI PC #" .. os.getComputerID())
    print("Na turtle: worker " .. os.getComputerID())
    while true do
        print("1 vykop | 2 stav | 3 pause | 4 pokracovat | 5 navrat/stop | 6 nastavenia | 7 uvolnit servis | 8 koniec | 9 podlaha")
        local choice = dialog.number("Volba", 2, 1, 9)
        if choice == 1 then newJob()
        elseif choice == 2 then
            local snapshot = control.snapshot(); local s = snapshot.summary
            print("Hotove " .. s.completed .. "/" .. s.total .. "; zostava " .. s.remaining)
            for _, id in ipairs(display.ids(snapshot)) do
                local w = snapshot.workers[id]
                print("#" .. id .. " " .. w.status .. " " .. w.age .. "s " .. tostring(w.error or "")
                    .. (w.pendingControl and (" caka povel " .. w.pendingControl) or ""))
            end
        elseif choice >= 3 and choice <= 5 then
            local target = dialog.number("ID turtle; 0 = vsetky", 0, 0)
            control.control(({ "pause", "resume", "stop" })[choice-2], target ~= 0 and target or nil)
        elseif choice == 6 then
            shell.run("fleet_setup"); control.settings = settings.load()
        elseif choice == 7 then
            print("Servis drzi: " .. tostring(control.state.locks.service and control.state.locks.service.owner or "nikto"))
            print("Uvolni ho iba ked turtle aj tunel fyzicky skontrolujes a cesta je volna.")
            if dialog.text("Pre uvolnenie napis VOLNE") == "VOLNE" then control.state.locks.service = nil; control.save() end
        elseif choice == 9 then newJob("floor")
        else control.save(); return end
    end
end
local function receive()
    while true do
        local sender, packet, protocol = rednet.receive(nil, 0.5)
        if sender then control.handle(sender, packet, protocol) end
        control.tick()
        if monitor then display.draw(monitor, control.snapshot(), 0, true) end
    end
end
parallel.waitForAny(receive, input)
