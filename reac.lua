local reac = peripheral.wrap("fissionReactorLogicAdapter_1")
local ref_interval = 0.5  --refresh interval
local log_init = true

local save_temp = 300  --target temp
local lim = 5  --limit zmeny teploty
local min_coolant = 10  --minimalna hodnota sodiku
local max_heat_coolant = 40  --maximalna hodnota horuceho sodiku

local log_pos = 20
local log_data = {
  { label = "Temp", val = temp, suffix = "°C"},
  { label = "Coolant", val = coolant, suffix = "%"},
  { label = "Heat Coolant", val = heat_coolant, suffix = "%"},
}
term.clear()

local function round(x, dec)  --zaokruhlenie hodnoty
  local m = 10^dec
  return math.floor(x * m)/m
end
local function temp()  --teplota reactoru
  local t = reac.getTemperature()-273.15
  return round(t,2)
end
local function coolant()  --mnozstvo sodiku v %
  local c = reac.getCoolantFilledPercentage()
  return round(c,3)
end
local function heat_coolant() --mnozstvo horuceho sodiku v %
  local c = reac.getHeatedCoolantFilledPercentage()
  return round(c,3)
end

local function scram_protocol()  --kontrola ci ma vypnut reaktor
  local scram = false
  local con = ""
  
  if coolant() <= min_coolant() then  --malo coolantu
    con = con .. "low coolant | "
    scram = true
  end
  if heat_coolant() >= max_heat_coolant() then  --vela heat coolantu
    con = con .. "heat coolant limit | "
    scram = true
  end

  if scram == true then  --scram
    reac.scram()
    print("Reactor bol odstaveny: " .. con)
    return true
  end

  return false
end

local function log()  --zobrazenie dat
  if log_init == true then  --prvotne nastavenie
    for i, data in ipairs(log_data) do
      term.setCursorPos(1,i)
      print(data.label .. ":")
    end
    log_init = false
  end

  for i, data in ipairs(log_data) do  --data
    term.setCursorPos(log_pos,i)
    print("        ")
    term.setCursorPos(log_pos,i)
    print(data.val .. " " .. data.suffix)
  end
end

while true do  --loop
  log()
  if scram_protocol() then
    break
  end
  sleep(ref_interval)
end
