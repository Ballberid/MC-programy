local config = require("config")
local nav = require("navigation")
local telemetry = require("telemetry")
local names = { [0] = "North (-Z)", "East (+X)", "South (+Z)", "West (-X)" }

local function ask(prompt)
    print(prompt)
    write("> ")
    return read()
end

local function normalize(value)
    return value:gsub("Á", "a"):gsub("á", "a"):lower():match("^%s*(.-)%s*$")
end

local function number(prompt, default, minimum, maximum)
    while true do
        local text = normalize(ask(prompt .. (default ~= nil and " [Enter = " .. default .. "]" or "")))
        local value = text == "" and default or tonumber(text)
        if value and value % 1 == 0 and math.abs(value) ~= math.huge
            and (not minimum or value >= minimum) and (not maximum or value <= maximum) then return value end
        print("Zadaj cele cislo v povolenom rozsahu.")
    end
end

local function yes(prompt, default)
    while true do
        local value = normalize(ask(prompt .. (default and " [A/n]" or " [a/N]")))
        if value == "" then return default end
        if value == "a" or value == "ano" or value == "y" or value == "yes" then return true end
        if value == "n" or value == "nie" or value == "no" then return false end
        print("Neplatna odpoved. Zadaj a/y alebo n.")
    end
end

local function heading(default)
    print("Smer: 0=North (-Z), 1=East (+X), 2=South (+Z), 3=West (-X)")
    return number("Smer", default, 0, 3)
end

local function point(default)
    default = default or {}
    return {
        x = number("X", default.x), y = number("Y", default.y), z = number("Z", default.z),
        direction = heading(default.direction),
    }
end

if not turtle then error("Setup spusti na turtle.", 0) end
print("Craftoria turtle - setup")
print("Ano = a alebo y, nie = n.")
print("Velke pismeno v A/n alebo a/N = volba po Enter.")
print("Zistovanie smeru moze urobit skusobny pohyb a vratit sa.")
local manual
if not yes("Zistit smer automaticky cez GPS?", true) then manual = heading() end
local ok, err = nav.init(manual)
if not ok then error("Inicializacia zlyhala: " .. tostring(err), 0) end
local c = config.defaults()
c.start = nav.getPosition()
c.home = nav.getPosition()
print("Start: " .. c.start.x .. ", " .. c.start.y .. ", " .. c.start.z .. " / " .. names[c.start.direction])
if not yes("Ma sa po skonceni vratit na toto miesto?", true) then
    print("Zadaj konecnu polohu turtle a smer:")
    c.home = point(c.home)
end

local offsets = { front = 0, right = 1, back = 2, left = 3 }
for _, entry in ipairs({ { "materials", "Material na stavanie" }, { "output", "Vykladanie" }, { "fuel", "Palivo" } }) do
    print("\nStanica: " .. entry[2])
    if yes("Nastavit tuto stanicu?", entry[1] == "fuel") then
        local station
        if yes("Je truhla vedla STARTOVACEJ polohy?", true) then
            local side
            repeat
                side = normalize(ask("Strana od povodneho smeru (front/right/back/left):"))
                if offsets[side] == nil then print("Zadaj front, right, back alebo left.") end
            until offsets[side] ~= nil
            station = {
                x = c.start.x, y = c.start.y, z = c.start.z,
                direction = (c.start.direction + offsets[side]) % 4, side = "front",
            }
        else
            print("Zadaj miesto KDE BUDE STAT TURTLE, nie suradnice bloku truhly:")
            station = point()
            local side
            repeat
                side = normalize(ask("Truhla z pristupovej polohy (front/up/down) [Enter = front]:"))
                if side == "" then side = "front" end
                if side ~= "front" and side ~= "up" and side ~= "down" then print("Zadaj front, up alebo down.") end
            until side == "front" or side == "up" or side == "down"
            station.side = side
        end
        c.stations[entry[1]] = station
    end
end
c.navigation.reserve = number("Rezerva paliva", 20, 0)
c.navigation.maxDetour = number("Maximalny rozsah obchadzky v kazdej osi", 12, 0, 64)
c.telemetry.enabled = yes("Posielat stav cez rednet?", true)
if c.telemetry.enabled then
    if yes("Posielat iba jednemu prijimacu podla ID?", false) then
        c.telemetry.receiverId = number("ID prijimaca", nil, 0)
    end
end
local label = ask("Nazov turtle (prazdne = ponechat):")
if label ~= "" then os.setComputerLabel(label) end
local saved, reason = config.save(c)
if not saved then error("Ulozenie zlyhalo: " .. tostring(reason), 0) end
nav.configure(c)
telemetry.log("Setup ulozeny do data/settings.txt")
print("Existenciu truhiel a trasy over cez test.lua. Setup ich este nenavstivil.")
