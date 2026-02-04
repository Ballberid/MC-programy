local reac = peripheral.wrap("fissionReactorLogicAdapter_1")
local boil = peripheral.wrap("boilerValve_0")
local turb = peripheral.wrap("turbineValve_0")

local ref_interval = 0.5  --refresh interval
local log_init = true
--reactor
local r_save_temp = 300  --target temp
local r_temp_lim = 5  --limit zmeny teploty
local r_min_coolant = 10  --minimalna hodnota sodiku
local r_max_heated = 40  --maximalna hodnota horuceho sodiku
local r_max_waste = 50 --maximalna hodnota waste
local r_min_fuel = 5 --minimalna hodnota paliva
local r_burn_step = 1 --velkost kroku nastavenia burn
--boiler
local b_min_water = 40  --minimalna hodnota vody
local b_max_heated = 50  --maximalna hodnota heated coolantu
local b_max_steam = 70  --maximalna hodnota pary
--turbina
local t_max_energy = 80  --maximalna hodnota energie

term.clear()

--basic
local function round(x, dec)  --zaokruhlenie hodnoty
  local m = 10^dec
  return math.floor(x * m)/m
end

--reactor
local function r_burn_rate()  --burn rate
  return reac.getBurnRate()
end
local function r_temp()  --teplota reactoru
  local t = reac.getTemperature()-273.15
  return round(t,2)
end
local function r_coolant()  --mnozstvo sodiku v %
  local c = reac.getCoolantFilledPercentage()*100
  return round(c,3)
end
local function r_heated()  --mnozstvo horuceho sodiku v %
  local h = reac.getHeatedCoolantFilledPercentage()*100
  return round(h,3)
end
local function r_waste()  --mnozstvo waste
  local w = reac.getWasteFilledPercentage()*100
  return round(w,2)
end
local function r_fuel()  --mnozstvo paliva
  local f = reac.getFuelFilledPercentage()*100
  return round(f,2)
end
local function r_status()  --status reactoru
  return reac.getStatus()
end

--boiler
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

--turbina
local function t_steam()
  local s = turb.getSteamFilledPercentage()
  return round(s,2)
end
local function t_energy()
  local e = turb.getEnergyFilledPercentage()
  return round(e,2)
end

--protokoly
local function scram_protocol()  --kontrola ci ma vypnut reaktor
  local scram = false
  local con = ""
  
  --reactor
  if r_coolant() <= r_min_coolant then  --malo coolantu
    con = con .. "r.coolant | "
    scram = true
  end
  if r_heated() >= r_max_heated then  --vela heat coolantu
    con = con .. "r.heated | "
    scram = true
  end
  if r_waste() >= r_max_waste then
    con = con .. "r.waste | "
    scram = true
  end
  if r_fuel() <= r_min_fuel then
    con = con .. "r.fuel | "
    scram = true
  end
  
  --boiler
  if b_water() <= b_min_water then
    con = con .. "b.water | "
    scram = true
  end
  if b_heated() >= b_max_heated then
    con = con .. "b.heated | "
    scram = true
  end
  if b_steam() >= b_max_steam then
    con = con .. "b.steam | "
    scram = true
  end

  --turbina
  if t_energy() >= t_max_energy then
    con = con .. "t.energy | "
    scram = true
  end

  --scram
  if scram == true then
    reac.scram()
    print("Reactor bol odstaveny: " .. con)
    return true
  end

  return false
end

local function burn_protocol() --ovladanie burn rate
  local increase = false
  local decrease = false
  --increase alebo decrease
  if r_temp() > (r_save_temp + r_temp_lim) then
    decrease = true
  end
  if r_temp() < (r_save_temp - r_temp_lim) then
    increase = true
  end
  --vykonanie akcie
  if decrease == true then
    increase = false
    reac.setBurnRate(r_burn_rate - r_burn_step)
  else if decrease == false and increase == true then
    reac.setBurnRate(r_burn_rate + r_burn_step)
  end
  end
end

local log_pos = 20
local log_clean = "    "
local log_data = {
  { label = "Reac Burn-Rate", val = r_burn_rate, suffix = "mB/t"},
  { label = "Reac Temp", val = r_temp, suffix = "°C"},
  { label = "Reac Coolant", val = r_coolant, suffix = "%"},
  { label = "Reac Heated", val = r_heated, suffix = "%"},
  { label = "Reac Waste", val = r_waste, suffix = "%"},
  { label = "Reac Fuel", val = r_fuel, suffix = "%"},
  { label = "Boil Water", val = b_water, suffix = "%"},
  { label = "Boil Coolant", val = b_coolant, suffix = "%"},
  { label = "Boil Heated", val = b_heated, suffix = "%"},
  { label = "Boil Steam", val = b_steam, suffix = "%"},
  { label = "Turb Steam", val = t_steam, suffix = "%"},
  { label = "Turb Energy", val = t_energy, suffix = "%"},
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
  if r_status() then
    burn_protocol()
  end
  sleep(ref_interval)
end
