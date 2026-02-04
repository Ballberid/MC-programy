local reac = peripheral.wrap("fissionReactorLogicAdapter_1")
local boil = peripheral.wrap("boilerValve_0")
local turb = peripheral.wrap("turbineValve_0")
local mon = peripheral.wrap("monitor_2")

local ref_interval = 0.5  --refresh interval

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
local log_offset_x = 10  --nazvy
local log_offset_y = 2
local log_p1_x = 1  --stranky
local log_p2_x = 40
local log_offset_data_1 = 17  --data
local log_offset_data_2 = 25

local reac_pos_x = log_p1_x
local reac_pos_y = 1
local reac_burn_pos = 1
local reac_temp_pos = 2
local reac_cool_pos = 3
local reac_heat_pos = 4
local reac_wast_pos = 5
local reac_fuel_pos = 6
local reac_log_1 = {
  { label = "Burn-Rate", pos = reac_burn_pos, val = r_burn_rate, suffix = "mB/t"},
  { label = "Temp", pos = reac_temp_pos, val = r_temp, suffix = "°C"},
  { label = "Coolant", pos = reac_cool_pos, val = r_coolant, suffix = "%"},
  { label = "Heated", pos = reac_heat_pos, val = r_heated, suffix = "%"},
  { label = "Waste", pos = reac_wast_pos, val = r_waste, suffix = "%"},
  { label = "Fuel", pos = reac_fuel_pos, val = r_fuel, suffix = "%"},
}

local boil_pos_x = log_p2_x
local boil_pos_y = 1
local boil_wat_pos = 1
local boil_cool_pos = 2
local boil_heat_pos = 3
local boil_steam_pos = 4
local boil_log_1 = {
  { label = "Water", pos = boil_wat_pos, val = b_water, suffix = "%"},
  { label = "Coolant", pos = boil_cool_pos, val = b_coolant, suffix = "%"},
  { label = "Heated", pos = boil_heat_pos, val = b_heated, suffix = "%"},
  { label = "Steam", pos = boil_steam_pos, val = b_steam, suffix = "%"},
}

local turb_pos_x = log_p2_x
local turb_pos_y = 20
local turb_steam_pos = 1
local turb_en_pos = 2
local turb_log_1 = {
  { label = "Steam", pos = turb_steam_pos, val = t_steam, suffix = "%"},
  { label = "Energy", pos = turb_en_pos, val = t_energy, suffix = "%"},
}

local function log_basic_text()
  local px = 1
  local py = 1
  --reactor text
  px = log_p1_x + log_offset_x
  py = reac_pos_y
  mon.setCursorPos(px, py)
  mon.write("Reaktor")
  --boiler text
  px = log_p2_x + log_offset_x
  py = boil_pos_y
  mon.setCursorPos(px, py)
  mon.write("Boiler")
  --turbine text
  px = log_p2_x + log_offset_x
  py = turb_pos_y
  mon.setCursorPos(px, py)
  mon.write("Turbina")
  
end

local function log_data_name()
        --reactor log init
    for i, data in ipairs(reac_log_1) do
      local p = (reac_pos_y + log_offset_y + (data.pos-1))
      mon.setCursorPos(reac_pos_x, p)
      mon.write(data.label .. ":")
    end
    --boiler log init
    for i, data in ipairs(boil_log_1) do
      local p = (boil_pos_y + log_offset_y + (data.pos-1))
      mon.setCursorPos(boil_pos_x, p)
      mon.write(data.label .. ":")
    end  
    --turbine log init
    for i, data in ipairs(turb_log_1) do
      local p = (turb_pos_y + log_offset_y + (data.pos-1))
      mon.setCursorPos(turb_pos_x, p)
      mon.write(data.label .. ":")
    end  
end

local function log_initialize()
  log_data_name()
  log_basic_text()
end

local function type_offset(type)
  local t = 0
  if type == 1 then
    t = log_offset_data_1
  elseif type == 2 then
    t = log_offset_data_2
  end
  return t
end

local function log_data(table, pos_x, pos_y, type)
  local x = pos_x + type_offset(type)
  for i, data in ipairs(table) do
    local p = (pos_y + log_offset_y + (data.pos-1))
    mon.setCursorPos(x, p)
    local text = data.val() .. " " .. data.siffix .. log_clean
    mon.write(text)
  end
end

local function log_reac_data()
  log_data(reac_log_1, reac_pos_x, reac_pos_y, 1)
end
local function log_boil_data()
  log_data(boil_log_1, boil_pos_x, boil_pos_y, 1)
end
local function log_turb_data()
  log_data(turb_log_1, turb_pos_x, turb_pos_y, 1)
end

local function log()  --zobrazenie dat
  log_reac_data()
  log_boil_data()
  log_turb_data()
end

--zaciatok kodu
log_initialize()

while true do --loop
  log()
  sleep(ref_interval)
end
