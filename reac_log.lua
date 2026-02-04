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
  else
    val = x / (1*10^6)
    rate = "M"
  end
  return val, rate
end
--reactor const methods
local function r_burn_rate_max()
  local v = reac.getMaxBurnRate()
  return v
end
local function r_coolant_max()
  local v = reac.getCoolantCapacity()
  local c, rate = reduce(v)
  local result = round(c,1) .. rate
  return result
end
local function r_heated_max()
  local v = reac.getHeatedCoolantCapacity()
  local c, rate = reduce(v)
  local result = round(c,1) .. rate
  return result
end
local function r_waste_max()
  local v = reac.getWasteCapacity()
  local c, rate = reduce(v)
  local result = round(c,1) .. rate
  return result
end
local function r_fuel_max()
  local v = reac.getFuelCapacity()
  local c, rate = reduce(v)
  local result = round(c,1) .. rate
  return result
end
--boiler const methods
local function b_water_max()
  local v = boil.getWaterCapacity()
  local c, rate = reduce(v)
  local result = round(c,1) .. rate
  return result
end
local function b_coolant_max()
  local v = boil.getCooledCoolantCapacity()
  local c, rate = reduce(v)
  local result = round(c,1) .. rate
  return result
end
local function b_heated_max()
  local v = boil.getHeatedCoolantCapacity()
  local c, rate = reduce(v)
  local result = round(c,1) .. rate
  return result
end
local function b_steam_max()
  local v = boil.getSteamCapacity()
  local c, rate = reduce(v)
  local result = round(c,1) .. rate
  return result
end
local function b_rate_max()
  local v = boil.getBoilRateCapacity()
  local c, rate = reduce(v)
  local result = round(c,1) .. rate
  return result
end
--turbine const methods
local function t_steam_max()
  local v = turb.getSteamCapacity()
  local c, rate = reduce(v)
  local result = round(c,1) .. rate
  return result
end
local function t_energy_max()
  local v = turb.getMaxEnergy()/2.5
  local c, rate = reduce(v)
  if c > 1*10^3 then
    c = c / 1000
    rate = "G"
  end
  local result = round(c,1) .. rate
  return result
end
--const
--reactor
local r_burn_max = 0
local r_cool_max = 0
local r_heat_max = 0
local r_wast_max = 0
local r_fl_max = 0
--boiler
local b_wat_max = 0
local b_cool_max = 0
local b_heat_max = 0
local b_stm_max = 0
local b_rt_max = 0
--turbina
local t_stm_max = 0
local t_en_max = 0
local function load_const()
  --reac
  r_burn_max = r_burn_rate_max()
  r_cool_max = r_coolant_max()
  r_heat_max = r_heated_max()
  r_wast_max = r_waste_max()
  r_fl_max = r_fuel_max()
  --boil
  b_wat_max = b_water_max()
  b_cool_max = b_coolant_max()
  b_heat_max = b_heated_max()
  b_stm_max = b_steam_max()
  b_rt_max = b_rate_max()
  --turb
  t_stm_max = t_steam_max()
  t_en_max = t_energy_max()
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
  local v = reac.getHeatedCoolant().amount
  local c, rate = reduce(v)
  local result = round(c,1) .. rate .. " / " .. r_heat_max
  return result
end
local function r_waste()  --mnozstvo waste
  local v = reac.getWaste().amount
  local c, rate = reduce(v)
  local result = round(c,1) .. rate .. " / " .. r_wast_max
  return result
end
local function r_fuel()  --mnozstvo paliva
  local v = reac.getFuel().amount
  local c, rate = reduce(v)
  local result = round(c,1) .. rate .. " / " .. r_fl_max
  return result
end
local function r_status()  --status reactoru
  return reac.getStatus()
end

local function r_burn_perc()
  local v = (reac.getBurnRate() / r_burn_max)*100
  return round(v,1)
end
local function r_cool_perc()
  local v = reac.getCoolantFilledPercentage()*100
  return round(v,1)
end
local function r_heat_perc()
  local v = reac.getHeatedCoolantFilledPercentage()*100
  return round(v,1)
end
local function r_wast_perc()
  local v = reac.getWasteFilledPercentage()*100
  return round(v,1)
end
local function r_fl_perc()
  local v = reac.getFuelFilledPercentage()*100
  return round(v,1)
end
--boiler
local function b_water()
  local v = boil.getWater().amount
  local c, rate = reduce(v)
  local result = round(c,1) .. rate .. " / " .. b_wat_max
  return result
end
local function b_coolant()
  local v = boil.getCooledCoolant().amount
  local c, rate = reduce(v)
  local result = round(c,1) .. rate .. " / " .. b_cool_max
  return result
end
local function b_heated()
  local v = boil.getHeatedCoolant().amount
  local c, rate = reduce(v)
  local result = round(c,1) .. rate .. " / " .. b_heat_max
  return result
end
local function b_steam()
  local v = boil.getSteam().amount
  local c, rate = reduce(v)
  local result = round(c,1) .. rate .. " / " .. b_stm_max
  return result
end
local function b_rate()
  local v = boil.getBoilRate()
  local c, rate = reduce(v)
  local result = round(c,1) .. rate .. " / " .. b_rt_max
  return result
end

local function b_wat_perc()
  local v = boil.getWaterFilledPercentage()*100
  return round(v,1)
end
local function b_cool_perc()
  local v = boil.getCooledCoolantFilledPercentage()*100
  return round(v,1)
end
local function b_heat_perc()
  local v = boil.getHeatedCoolantFilledPercentage()*100
  return round(v,1)
end
local function b_stm_perc()
  local v = boil.getSteamFilledPercentage()*100
  return round(v,1)
end
local function b_rt_perc()
  local v = (boil.getBoilRate()/b_rt_max)*100
  return round(v,1)
end
--turbina
local function t_steam()
  local v = turb.getSteam().amount
  local c, rate = reduce(v)
  local result = round(c,1) .. rate .. " / " .. t_stm_max
  return result
end
local function t_energy()
  local v = turb.getEnergy()/2.5
  local c, rate = reduce(v)
  if c > 1*10^3 then
    c = c / 1000
    rate = "G"
  end
  local result = round(c,1) .. rate .. " / " .. t_en_max
  return result
end

local function t_stm_perc()
  local v = turb.getSteamFilledPercentage()*100
  return round(v,1)
end
local function t_en_perc()
  local v = turb.getEnergyFilledPercentage()*100
  return round(v,1)
end
----------------------
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
  { label = "Heated", pos = reac_heat_pos, val = r_heated, suffix = "mB", last_len = 0},
  { label = "Waste", pos = reac_wast_pos, val = r_waste, suffix = "mB", last_len = 0},
  { label = "Fuel", pos = reac_fuel_pos, val = r_fuel, suffix = "mB", last_len = 0},
}
local reac_log_2 = {
  { label = "Burn %", pos = reac_burn_pos, val = r_burn_perc, suffix = "%", last_len = 0},
  { label = "Cool %", pos = reac_cool_pos, val = r_cool_perc, suffix = "%", last_len = 0},
  { label = "Heat %", pos = reac_heat_pos, val = r_heat_perc, suffix = "%", last_len = 0},
  { label = "Wast %", pos = reac_wast_pos, val = r_wast_perc, suffix = "%", last_len = 0},
  { label = "Fuel %", pos = reac_fuel_pos, val = r_fl_perc, suffix = "%", last_len = 0},
}

local boil_pos_x = log_p2_x
local boil_pos_y = 1
local boil_wat_pos = 1
local boil_cool_pos = 2
local boil_heat_pos = 3
local boil_steam_pos = 4
local boil_rate_pos = 5
local boil_log_1 = {
  { label = "Water", pos = boil_wat_pos, val = b_water, suffix = "mB", last_len = 0},
  { label = "Coolant", pos = boil_cool_pos, val = b_coolant, suffix = "mB", last_len = 0},
  { label = "Heated", pos = boil_heat_pos, val = b_heated, suffix = "mB", last_len = 0},
  { label = "Steam", pos = boil_steam_pos, val = b_steam, suffix = "mB", last_len = 0},
  { label = "Boil", pos = boil_rate_pos, val = b_rate, suffix = "mB/t", last_len = 0},
}
local boil_log_2 = {
  { label = "Water %", pos = boil_wat_pos, val = b_wat_perc, suffix = "%", last_len = 0},
  { label = "Coolant %", pos = boil_cool_pos, val = b_cool_perc, suffix = "%", last_len = 0},
  { label = "Heated %", pos = boil_heat_pos, val = b_heat_perc, suffix = "%", last_len = 0},
  { label = "Steam %", pos = boil_steam_pos, val = b_stm_perc, suffix = "%", last_len = 0},
  { label = "Boil %", pos = boil_rate_pos, val = b_rt_perc, suffix = "%", last_len = 0},
}

local turb_pos_x = log_p2_x
local turb_pos_y = 20
local turb_steam_pos = 1
local turb_en_pos = 2
local turb_log_1 = {
  { label = "Steam", pos = turb_steam_pos, val = t_steam, suffix = "mB", last_len = 0},
  { label = "Energy", pos = turb_en_pos, val = t_energy, suffix = "FE", last_len = 0},
}
local turb_log_2 = {
  { label = "Steam %", pos = turb_steam_pos, val = t_stm_perc, suffix = "%", last_len = 0},
  { label = "Energy %", pos = turb_en_pos, val = t_en_perc, suffix = "%", last_len = 0},
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
local function log_draw_lines()
  local w, h = mon.getSize()
  
  for i = 1, w do  --horna ciara
    mon.setCursorPos(i, reac_pos_y + (log_offset_y/2))
    mon.write("-")
  end
  for i = 1, h do  --stredova ciara
    mon.setCursorPos((log_p2_x-1), i)
    mon.write("|")
  end
  for i = 1, (w-log_p2_x) do --ohranicenie turbiny (vrch)
    mon.setCursorPos((log_p2_x+(i-1)), (turb_pos_y-1))
    mon.write("-")
  end
  for i = 1, (w-log_p2_x) do --ohranicenie turbiny (spodok)
    mon.setCursorPos((log_p2_x+(i-1)), (turb_pos_y+1))
    mon.write("-")
  end
end

local function log_initialize()
  log_basic_text()
  log_data_name()
  log_draw_lines()
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
  log_data(boil_log_2, boil_pos_x, boil_pos_y, 2)
end
local function log_turb_data()
  log_data(turb_log_1, turb_pos_x, turb_pos_y, 1)
  log_data(turb_log_2, turb_pos_x, turb_pos_y, 2)
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
