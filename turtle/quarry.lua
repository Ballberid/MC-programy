local config = require("config")
local mining = require("mining")
local telemetry = require("telemetry")

local function ask(prompt)
    print(prompt)
    write("> ")
    return read():gsub("Á", "a"):gsub("á", "a"):lower():match("^%s*(.-)%s*$")
end

local function number(prompt, minimum, maximum)
    while true do
        local value = tonumber(ask(prompt))
        if value and value % 1 == 0 and math.abs(value) ~= math.huge
            and (not minimum or value >= minimum) and (not maximum or value <= maximum) then return value end
        print("Zadaj platne cele cislo.")
    end
end

local function yes(prompt, default)
    while true do
        local value = ask(prompt .. (default and " [A/n]" or " [a/N]"))
        if value == "" then return default end
        if value == "a" or value == "y" or value == "ano" or value == "yes" then return true end
        if value == "n" or value == "nie" or value == "no" then return false end
        print("Zadaj a/y alebo n.")
    end
end

local function corner(name)
    print(name .. " - suradnice krajnych blokov:")
    return { x = number("X"), y = number("Y"), z = number("Z") }
end

if not turtle then error("Quarry spusti na mining turtle.", 0) end
local settings, configErr = config.load()
if not settings then error("Najprv spusti setup: " .. tostring(configErr), 0) end
telemetry.configure(settings.telemetry)
print("Kopanie kvadra. Velke pismeno = volba po Enter.")
print("Rezim: plna nadrz + alternativne vstupy.")
local a, b = corner("Prvy roh"), corner("Druhy protilahly roh")
local box, areaErr = mining.validateArea(a, b)
if not box then error("Neplatna oblast: " .. tostring(areaErr), 0) end
print("Od: " .. box.min.x .. "," .. box.min.y .. "," .. box.min.z)
print("Do: " .. box.max.x .. "," .. box.max.y .. "," .. box.max.z)
print("Rozmery X/Y/Z: " .. box.size.x .. "/" .. box.size.y .. "/" .. box.size.z)
print("Pocet miest vratane oboch rohov: " .. box.volume)
if not yes("Spustit kopanie tejto oblasti?", false) then print("Zrusene."); return end
local heading
if not yes("Zistit aktualny smer automaticky cez GPS?", true) then
    print("0=North (-Z), 1=East (+X), 2=South (+Z), 3=West (-X)")
    heading = number("Aktualny smer turtle", 0, 3)
end
local ok, err, progress = telemetry.capture(mining.run, a, b, heading)
if not ok then
    print("Dokoncene miesta: " .. (progress and progress.visited or 0) .. "/" .. box.volume)
    if progress and progress.returnError then print("Navrat zlyhal: " .. tostring(progress.returnError)) end
    error(tostring(err), 0)
end
