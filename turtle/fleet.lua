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
            local optional = role == "materials" and kind == "quarry"
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
    local horizontal=kind=="floor" or kind=="ceiling"
    if horizontal then print(kind=="floor" and "Podlaha: turtle chodi na Y+1 a kladie pod seba." or "Strop: turtle chodi na Y-1 a kladie nad seba.") end
    local a = dialog.point("Prvy roh oblasti", true)
    local b = horizontal and dialog.flatPoint("Protilahly roh oblasti",a.y) or dialog.point("Protilahly roh oblasti", true)
    local block
    local corners=false
    if kind=="walls" then
        print("Steny: styri bocne plochy, bez podlahy a stropu.")
        print("Rohy potrebuju pristup zvonka; bez rohov stavia zvnutra.")
        corners=dialog.yes("Spravit aj rohy?",false)
    end
    if kind~="quarry" then
        local plan=kind=="walls" and require("wall_plan") or (kind=="ceiling" and require("ceiling_plan") or require("floor_plan"))
        local valid, invalid = plan.new(a,b,kind=="walls" and {includeCorners=corners} or nil)
        if not valid then print(invalid); return end
        block = dialog.text("ID bloku; Enter = vzorka z materialovej truhly", "")
        if block == "" then block = nil end
    end
    local c = settings.load(); control.settings = c
    local stations = pickStations(c, kind); if not stations then return end
    local floor
    if c.tunnel then floor = dialog.choose("Pracovne poschodie", c.tunnel.floors) end
    local parts,reason,wallArea
    if kind=="walls" then parts,reason,wallArea=model.splitWalls(a,b,count,{includeCorners=corners})
    else parts,reason=model.split(a,b,count) end
    if not parts then print(reason); return end
    if wallArea then
        local g=wallArea.opening
        print("Spolocny priechod: "..g.x..","..g.y..","..g.z.."; pristup zvonka musi byt volny.")
        print("Posledna turtle ho uzavrie po navrate ostatnych do dokov.")
    end
    for i, part in ipairs(parts) do print("#" .. selected[i] .. ": " .. part.total .. " miest") end
    if not dialog.yes(kind~="quarry" and "Spustit stavanie?" or "Spustit spolocny vykop?", false) then return end
    local started, startErr = control.start(a, b, selected, stations, c.tunnel, floor, { kind = kind, block = block,includeCorners=corners })
    print(started and "Ulohy odoslane. Potvrdenia sleduj na monitore." or ("Nespustene: " .. tostring(startErr)))
end
local function controlTarget(action)
    local scope=dialog.number("Ovladat: 1 turtle, 2 celu ulohu, 3 vsetky",1,1,3)
    if scope==2 then
        local jobs=control.snapshot().jobs or {}
        if #jobs==0 then print("Ziadne ulohy."); return end
        for index,job in ipairs(jobs) do
            print(index.." - Uloha #"..job.number.." "..job.kind.." "..job.status.." ("..table.concat(job.workers,",")..")")
        end
        local selected=dialog.number("Vyber ulohu zo zoznamu",nil,1,#jobs)
        control.control(action,nil,jobs[selected].id)
    elseif scope==3 then control.control(action)
    else
        local target=dialog.number("ID turtle; 0 = vsetky",0,0)
        control.control(action,target~=0 and target or nil)
    end
end
local function input()
    print("RIADIACI PC #" .. os.getComputerID())
    print("Na turtle: worker " .. os.getComputerID())
    while true do
        print("NOVE ULOHY: 1 vykop | 2 podlaha | 3 strop | 4 steny")
        print("OVLADANIE: 5 stav | 6 pauza | 7 pokracovat | 8 navrat/stop | 9 reset do idle")
        print("NASTAVENIA: 10 zakladna | 11 uvolnit rezervacie")
        print("0 koniec")
        local choice = dialog.number("Volba", 5, 0, 11)
        if choice == 1 then newJob()
        elseif choice == 2 then newJob("floor")
        elseif choice == 3 then newJob("ceiling")
        elseif choice == 4 then newJob("walls")
        elseif choice == 5 then
            local snapshot = control.snapshot(); local s = snapshot.summary
            print("Hotove " .. s.completed .. "/" .. s.total .. "; zostava " .. s.remaining)
            for _,job in ipairs(snapshot.jobs or {}) do
                print("Uloha #"..job.number.." "..job.kind.." "..job.status..": "..job.summary.completed.."/"..job.summary.total)
            end
            for _,group in ipairs(display.groups(snapshot)) do
                print(group.title..": "..group.completed.."/"..group.total)
                for _, id in ipairs(group.ids) do
                local w = snapshot.workers[id]
                print("#" .. id .. " uloha "..tostring(w.jobNumber or "-").." " .. display.activity(w) .. " " .. w.age .. "s " .. tostring(w.error or "")
                    .. (w.pendingControl and (" caka povel " .. w.pendingControl) or ""))
                end
            end
        elseif choice >= 6 and choice <= 8 then
            controlTarget(({ "pause", "resume", "stop" })[choice-5])
        elseif choice == 10 then
            shell.run("fleet_setup"); control.settings = settings.load()
        elseif choice == 11 then
            print("Servis drzia: " .. table.concat(model.serviceOwners(control.state.locks),","))
            print("Tunel drzia: " .. table.concat(model.tunnelOwners(control.state.locks),","))
            print("Uvolni rezervacie iba ked turtle aj tunel fyzicky skontrolujes a cesta je volna.")
            if dialog.text("Pre uvolnenie napis VOLNE") == "VOLNE" then
                control.state.locks.service, control.state.locks.tunnel = nil, nil
                for resource in pairs(control.state.locks) do
                    if resource:match("^tunnel:") or resource:match("^door:") or resource:match("^station:") or resource:match("^wallgate:") then control.state.locks[resource]=nil end
                end
                control.save()
            end
        elseif choice==9 then
            controlTarget("reset")
        else control.save(); return end
    end
end
local function receive()
    local lastDraw=-math.huge
    while true do
        local sender, packet, protocol = rednet.receive(nil, 0.5)
        if sender then control.handle(sender, packet, protocol) end
        control.tick()
        if monitor and os.clock()-lastDraw>=1 then
            lastDraw=os.clock(); display.draw(monitor, control.snapshot(), 0, true)
        end
    end
end
parallel.waitForAny(receive, input)
