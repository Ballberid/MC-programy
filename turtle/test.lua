-- Diagnostics in-game. `test check` is read-only. `test` opens the menu.
local config = require("config")
local nav = require("navigation")
local fuel = require("fuel")
local inv = require("inventory")
local stations = require("stations")
local supplies = require("supplies")
local telemetry = require("telemetry")
local network = require("network")
local paths = require("pathfinding")
local args = { ... }

local function show(ok, err)
    print(ok and "OK" or ("CHYBA: " .. tostring(err)))
end

local function confirm(message)
    print(message)
    write("Spustit? Napis ANO: ")
    return read() == "ANO"
end

local function check()
    print("Diagnostika bez pohybu a bez spotreby predmetov:")
    local c, err = config.load()
    print("Nastavenia: " .. (c and "OK" or tostring(err)))
    if c then nav.configure(c) end
    print("Palivo: " .. tostring(fuel.level()))
    print("Volne sloty: " .. inv.freeSlots())
    for _, item in ipairs(inv.snapshot().items) do print(item.slot .. ": " .. item.name .. " x" .. item.count) end
    local p, gpsErr = require("position").locate()
    print("GPS: " .. (p and (p.x .. ", " .. p.y .. ", " .. p.z) or tostring(gpsErr)))
    local modems = {}
    for _, name in ipairs(peripheral.getNames()) do
        if peripheral.hasType(name, "modem") then modems[#modems + 1] = name end
    end
    print("Modemy: " .. (#modems > 0 and table.concat(modems, ", ") or "ziadny"))
    if c then
        for name, s in pairs(c.stations) do
            print(name .. ": " .. s.x .. "," .. s.y .. "," .. s.z .. " dir=" .. s.direction .. " side=" .. s.side)
        end
    end
end

local function plannerTest()
    local start = { x = 0, y = 0, z = 0 }
    local goal = { x = 3, y = 0, z = 0 }
    paths.clear(); paths.mark(start, true); paths.mark({ x = 1, y = 0, z = 0 }, false)
    local route, err = paths.find(start, goal, { bounds = paths.bounds(start, goal, 2), maxNodes = 500 })
    print("Simulovana prekazka, ziadny fyzicky pohyb:")
    show(route and #route == 5, err or "unexpected_route")
    if route then print("Dlzka obchadzky: " .. #route) end
    -- Test uses the real planner but discards its artificial map afterwards.
    paths.clear()
    local p = nav.getPosition()
    if p then paths.mark(p, true) end
    print("Mapa bola vymazana. Pred pracou znova over palivovu stanicu.")
end

local function ensurePosition()
    if nav.getPosition() then return true end
    return nav.init()
end

if not turtle then error("Diagnostiku spusti na turtle.", 0) end
if args[1] == "check" then check(); return end
if args[1] then error("Pouzitie: test [check]", 0) end
while true do
    print("\n1 Stav | 2 Smer/GPS | 3 Planner | 4 Telemetria")
    print("5 Doplnit palivo z inventara | 6 Overit truhly a vratit sa")
    print("7 Presun na suradnice a spat | 8 Navrat domov")
    print("9 Zasobovanie | 0 Koniec")
    write("> ")
    local choice = read()
    if choice == "0" then break end
    local ran, failure = pcall(function()
        if choice == "1" then check()
        elseif choice == "2" and confirm("Zistenie smeru moze turtle posunut a vratit spat.") then
            show(nav.init())
            if nav.getPosition() then print(textutils.serialize(nav.getPosition())) end
        elseif choice == "3" then plannerTest()
        elseif choice == "4" then
            local c = config.load()
            if c then nav.configure(c) end
            local ready, err = network.open()
            if not ready then show(false, err) else show(telemetry.log("Diagnosticka sprava")) end
        elseif choice == "5" and confirm("Spotrebuje palivove predmety z inventara.") then
            print("Palivo: " .. tostring(fuel.refuel()))
        elseif choice == "6" and confirm("Navstivi nastavene truhly a po kazdej sa vrati.") then
            local c, err = config.load()
            if not c then show(false, err); return end
            local ready, reason = ensurePosition()
            if not ready then show(false, reason); return end
            for _, name in ipairs({ "fuel", "materials", "output" }) do
                if c.stations[name] then
                    print("Overujem " .. name)
                    local ok, why = stations.verify(name)
                    show(ok, why)
                    if not ok then break end
                end
            end
        elseif choice == "7" then
            write("X: "); local x = tonumber(read())
            write("Y: "); local y = tonumber(read())
            write("Z: "); local z = tonumber(read())
            if not config.isPoint({ x = x, y = y, z = z }) then show(false, "invalid_target"); return end
            if not confirm("Presunie sa na zadane miesto a pokusi sa vratit.") then return end
            local ready, reason = ensurePosition()
            if not ready then show(false, reason); return end
            local start = nav.getPosition()
            show(nav.moveToCoord(x, y, z, { anchor = start }))
            show(nav.moveToCoord(start.x, start.y, start.z, { anchor = start, knownOnly = true, direction = start.direction }))
        elseif choice == "8" and confirm("Presunie sa na konecnu polohu zo setupu.") then
            show(nav.goHome())
        elseif choice == "9" and confirm("Overi palivovu truhlu; moze doplnit palivo a vylozit inventar.") then
            local ok, err = supplies.prepare()
            if not ok then show(false, err); return end
            show(supplies.ensure({ moves = 10, freeSlots = 1 }))
        end
    end)
    if not ran then
        if tostring(failure):find("Terminated", 1, true) then error(failure, 0) end
        print("CHYBA: " .. tostring(failure))
    end
end
