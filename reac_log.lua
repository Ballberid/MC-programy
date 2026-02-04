local reac = peripheral.wrap("fissionReactorLogicAdapter_1")
local boil = peripheral.wrap("boilerValve_0")
local turb = peripheral.wrap("turbineValve_0")
local mon = peripheral.wrap("monitor_2")

local ref_interval = 0.5  --refresh interval
local log_init = true

mon.setTextScale(0.5)
mon.clear()

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

local log_clean = "    "
local log_offset_x = 10
local log_offset_y = 2
local log_p1_x = 1
local log_p2_x = 25

local reac_pos_x = 17
local reac_pos_y = 1
local reac_log = {
  { label = "Reac Burn-Rate", val = r_burn_rate, suffix = "mB/t"},
  { label = "Reac Temp", val = r_temp, suffix = "°C"},
  { label = "Reac Coolant", val = r_coolant, suffix = "%"},
  { label = "Reac Heated", val = r_heated, suffix = "%"},
  { label = "Reac Waste", val = r_waste, suffix = "%"},
  { label = "Reac Fuel", val = r_fuel, suffix = "%"},
}

local boil_pos_x = 37
local boil_pos_y = 1
local boil_log = {
  { label = "Boil Water", val = b_water, suffix = "%"},
  { label = "Boil Coolant", val = b_coolant, suffix = "%"},
  { label = "Boil Heated", val = b_heated, suffix = "%"},
  { label = "Boil Steam", val = b_steam, suffix = "%"},
}

local turb_pos_x = 37
local turb_pos_y = 20
local turb_log = {
  { label = "Turb Steam", val = t_steam, suffix = "%"},
  { label = "Turb Energy", val = t_energy, suffix = "%"},
}

local function log()  --zobrazenie dat
  if log_init == true then  --prvotne nastavenie
    --reactor log init
    local px = 1
    local py = 1
    
    px = log_p1_x + log_offset_x
    py = reac_pos_y + log_offset_y
    mon.setCursorPos(px, py)
    mon.write("Reaktor")
    for i, data in ipairs(reac_log) do
      local p = (reac_pos_y + log_offset_y + (i-1))
      mon.setCursorPos(log_p1_x, p)
      mon.write(data.label .. ":")
    end
    --boiler log init
    
    --turbine log init
    
    log_init = false
  end

  for i, data in ipairs(reac_log) do  --reactor data
    local p = (reac_pos_y + log_offset_y + (i-1))
    mon.setCursorPos(reac_pos_x, p)
    mon.write(data.val() .. " " .. data.suffix .. log_clean)
  end
end

while true do  --loop
  log()
  sleep(ref_interval)
end
