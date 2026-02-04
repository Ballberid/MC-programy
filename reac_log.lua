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
local function reduce(x)
  local val = 0
  local rate = 0
  
  if x < (1*10^3) then
    val = x
    rate = ""
  elseif x < (1*10^6) then
    val = x / (1*10^3)
    rate = "K"
  elseif x < (1*10^9) then
    val = x / (1*10^6)
    rate = "M"
  end
  return val, rate
end
--reactor const
local function r_coolant_max()
  local v = reac.getCoolantCapacity()
  local c, rate = reduce(v)
  local result = round(c,1) .. rate
  return result
end
local function r_burn_rate_max()
  local v = reac.getMaxBurnRate()
  return v
end
--const
local r_burn_max = 0
local r_cool_max = 0
local function load_const()
  r_cool_max = r_coolant_max()
  r_burn_max = r_burn_rate_max()
end

--reactor
local function r_stat()
  local val = "???"
  if reac.getStatus() then
    val = "ONLINE"
  else
    val = "OFFLINE"
  end
  return val
end
local function r_burn_rate()  --burn rate
  return reac.getBurnRate() .. " / " .. r_burn_max
end
local function r_temp()  --teplota reactoru
  local t = reac.getTemperature()-273.15
  return round(t,2)
end
local function r_coolant()  --mnozstvo sodiku v %
  local v = reac.getCoolant().amount  --mB to B
  local c, rate = reduce(v)
  local result = round(c,1) .. rate .. " / " .. r_cool_max
  return result
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

local function r_burn_perc()
  local v = (reac.getBurnRate() / r_burn_max)*100
  return round(v,1)
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

local log_offset_x = 10  --nazvy
local log_offset_y = 2
local log_p1_x = 1  --stranky
local log_p2_x = 40
local log_offset_data_1 = 9  --data
local log_offset_data_2 = 30

local reac_pos_x = log_p1_x
local reac_pos_y = 1
local reac_stat_pos = 1
local reac_burn_pos = 2
local reac_temp_pos = 3
local reac_cool_pos = 4
local reac_heat_pos = 5
local reac_wast_pos = 6
local reac_fuel_pos = 7
local reac_log_1 = {
  { label = "Status", pos = reac_stat_pos, val = r_stat, suffix = "", last_len = 0},
  { label = "Burn", pos = reac_burn_pos, val = r_burn_rate, suffix = "mB/t", last_len = 0},
  { label = "Temp", pos = reac_temp_pos, val = r_temp, suffix = "°C", last_len = 0},
  { label = "Coolant", pos = reac_cool_pos, val = r_coolant, suffix = "mB", last_len = 0},
  { label = "Heated", pos = reac_heat_pos, val = r_heated, suffix = "%", last_len = 0},
  { label = "Waste", pos = reac_wast_pos, val = r_waste, suffix = "%", last_len = 0},
  { label = "Fuel", pos = reac_fuel_pos, val = r_fuel, suffix = "%", last_len = 0},
}
local reac_log_2 = {
  { label = "Burn %", pos = reac_burn_pos, val = r_burn_perc, suffix = "%", last_len = 0},
}

local boil_pos_x = log_p2_x
local boil_pos_y = 1
local boil_wat_pos = 1
local boil_cool_pos = 2
local boil_heat_pos = 3
local boil_steam_pos = 4
local boil_log_1 = {
  { label = "Water", pos = boil_wat_pos, val = b_water, suffix = "%", last_len = 0},
  { label = "Coolant", pos = boil_cool_pos, val = b_coolant, suffix = "%", last_len = 0},
  { label = "Heated", pos = boil_heat_pos, val = b_heated, suffix = "%", last_len = 0},
  { label = "Steam", pos = boil_steam_pos, val = b_steam, suffix = "%", last_len = 0},
}

local turb_pos_x = log_p2_x
local turb_pos_y = 20
local turb_steam_pos = 1
local turb_en_pos = 2
local turb_log_1 = {
  { label = "Steam", pos = turb_steam_pos, val = t_steam, suffix = "%", last_len = 0},
  { label = "Energy", pos = turb_en_pos, val = t_energy, suffix = "%", last_len = 0},
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
  log_basic_text()
  log_data_name()
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
    local text = data.val() .. " " .. data.suffix

    local last = tonumber(data.last_len)  --clean line
    if string.len(text) < data.last_len then
      local clean = ""
      for i = 1, data.last_len do
        clean = clean .. " "
      end
      mon.write(clean)
      mon.setCursorPos(x, p)
    end

    data.last_len = string.len(text)
    mon.write(text)
  end
end

local function log_reac_data()
  log_data(reac_log_1, reac_pos_x, reac_pos_y, 1)
  log_data(reac_log_2, reac_pos_x, reac_pos_y, 2)
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
load_const()

while true do --loop
  log()
  sleep(ref_interval)
end
