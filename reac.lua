local reac = peripheral.wrap("fissionReactorLogicAdapter_1")
local boil = peripheral.wrap("boilverValve_0")
local ref_interval = 0.5  --refresh interval
local log_init = true

local r_save_temp = 300  --target temp
local r_lim = 5  --limit zmeny teploty
local r_min_coolant = 10  --minimalna hodnota sodiku
local r_max_heated = 40  --maximalna hodnota horuceho sodiku

term.clear()

local function round(x, dec)  --zaokruhlenie hodnoty
  local m = 10^dec
  return math.floor(x * m)/m
end
local function r_temp()  --teplota reactoru
  local t = reac.getTemperature()-273.15
  return round(t,2)
end
local function r_coolant()  --mnozstvo sodiku v %
  local c = reac.getCoolantFilledPercentage()*100
  return round(c,3)
end
local function r_heated() --mnozstvo horuceho sodiku v %
  local h = reac.getHeatedCoolantFilledPercentage()*100
  return round(c,3)
end

local function b_water()
  local w = boil.getWaterFilledPercentage()*100
  return round(w,3)
end
local function b_coolant()
  local c = boil.getCooledCoolantFilledPercentage()*100
  return round(c,3)
end
local function b_heated()
  local h = boil.getHeatedCoolantFilledPercentage()*100
  return round(h,3)
end
local function b_steam()
  local s = boil.getSteamFilledPercentage()*100
  return round(s,2)
end

local function scram_protocol()  --kontrola ci ma vypnut reaktor
  local scram = false
  local con = ""
  
  if r_coolant() <= r_min_coolant then  --malo coolantu
    con = con .. "r.coolant | "
    scram = true
  end
  if r_heat_coolant() >= r_max_heated then  --vela heat coolantu
    con = con .. "r.heated | "
    scram = true
  end

  if scram == true then  --scram
    reac.scram()
    print("Reactor bol odstaveny: " .. con)
    return true
  end

  return false
end



local log_pos = 20
local log_clean = "    "
local log_data = {
  { label = "Reac Temp", val = r_temp, suffix = "°C"},
  { label = "Reac Coolant", val = r_coolant, suffix = "%"},
  { label = "Reac Heated", val = r_heated, suffix = "%"},
  { label = "Boil Water", val = b_water, suffix = "%"},
  { label = "Boil Coolant", val = b_coolant, suffix = "%"},
  { label = "Boil Heated", val = b_heated, suffix = "%"},
  { label = "Boil Steam", val = b_steam, suffix = "%"},
}

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
    print(data.val() .. " " .. data.suffix .. log_clean)
  end
end

while true do  --loop
  log()
  if scram_protocol() then
    break
  end
  sleep(ref_interval)
end
