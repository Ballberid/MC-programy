local reac = peripheral.wrap("fissionReactorLogicAdapter_1")
local boil = peripheral.wrap("boilerValve_0")
local turb = peripheral.wrap("turbineValve_0")
local mon = peripheral.wrap("monitor_0")

local ref_interval = 0.2  --refresh interval

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
      mon.setCursorPos(1,i)
      mon.write(data.label .. ":")
    end
    log_init = false
  end

  for i, data in ipairs(log_data) do  --data
    mon.setCursorPos(log_pos,i)
    mon.write(data.val() .. " " .. data.suffix .. log_clean)
  end
end

while true do  --loop
  log()
  sleep(ref_interval)
end
