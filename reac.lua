local reac = peripheral.wrap("fissionReactorLogicAdapter_1")
local boil = peripheral.wrap("boilerValve_0")
local turb = peripheral.wrap("turbineValve_0")
local mon = peripheral.wrap("monitor_3")

local interval = 0.1  --refresh interval
local interval_inc = 1  
local interval_dec = 0.1
local dead_zone = 1
local force_burn_multiplier = 1.5
local undo_lim = 10
local undo_pos = 0
local undo_step = 0.1
local undo = false
--reactor
local r_burn_step_max = 2
local r_burn_step_min = 0.01

local mon_pos = 1
local w, h = mon.getSize()
local mon_clear = false
mon.clear()
mon.setTextScale(0.5)
mon.setCursorPos(1,mon_pos)
term.clear()

--basic function
local function round(x, dec)  --zaokruhlenie hodnoty
  local m = 10^dec
  return math.floor(x * m)/m
end
local function clamp(x, min, max)
  local lo = math.min(min, max)
  local hi = math.max(min, max)
  if x < lo then return lo end
  if x > hi then return hi end
  return x
end
local function map(x, inMin, inMax, outMin, outMax)
  if inMax == inMin then return outMin end
  local v = (x - inMin) * (outMax - outMin) / (inMax - inMin) + outMin
  return clamp(v, outMin, outMax)
end
local function compare(burn_old, burn_new)
  local burn = burn_old
  local con = 0
  if burn_old < burn_new then
    burn = burn_old
    con = 0
  elseif burn_old > burn_new then
    burn = burn_new
    con = 1
  else
    burn = burn_old
    con = 2
  end
  return burn, con
end

local function log(step, burn, cond, cb)
  step = round(step,2)
  burn = round(burn,2)
  local can_burn = 0
  if cb == true then
    can_burn = 1
  else
    can_burn = 0
  end
  local text = can_burn .. " | " .. "step: " .. step .. " | burn: " .. burn .. " | " .. cond
  print(text)
  mon_pos = mon_pos + 1
  if mon_pos >= h then
    mon_pos = 1
    mon_clear = true
  end
  if mon_clear == true then
    mon.setCursorPos(1, mon_pos)
    mon.write("                                            ")
    mon.setCursorPos(1, (mon_pos+1))
    mon.write("--------------------------------------------")
  end
  mon.setCursorPos(1, mon_pos)
  mon.write(text)
end
  
--reactor
local function r_status()  --status reactoru
  return reac.getStatus()
end
local function r_temp()  --teplota reactoru
  return reac.getTemperature()-273.15
end
local function r_coolant()  --mnozstvo sodiku v %
  return reac.getCoolantFilledPercentage()*100
end
local function r_burn()
  return reac.getBurnRate()
end
--boiler
local function b_water()
  return boil.getWaterFilledPercentage()*100
end

--reactor controll
local function calc_step(x, lim, scram, safe)
  if safe == nil then safe = 100 end
  local step = 0
  local cond = false
  if x > lim + dead_zone then
    step = map(x, lim, safe, r_burn_step_min, r_burn_step_max)
    step = round(step, 2)
  elseif x < lim - dead_zone then
    step = map(x, lim, scram, r_burn_step_min, r_burn_step_max)
    step = round(step, 2)
    step = step*(-1)
  end

  return step
end
local function make_con(con, type_con, c)
  local result = ""
  if c == 0 then
    result = con
  elseif c == 1 then
    result = type_con
  elseif c == 2 then
    result = con .. " | " .. type_con
  end

  return result
end
local function can_set_burn(current, last, lim, cb)
  local result = false
  if cb == true then
    if current >= last and current >= lim then
      result = true
    elseif current >= last and current < lim then
      result = false
    elseif current < last and current < lim then
      result = true
    elseif current < last and current >= lim then
      result = false
    end
  end
  if current < lim and (lim/current) > force_burn_multiplier then
      result = true
  end
  
  return result
end
local function r_set_burn(burn)
  burn = clamp(burn, 0, 1920)
  burn = round(burn, 2)
  reac.setBurnRate(burn)
end

local function calc_burn(val, min, scram, burn_new, burn_now)
  local s = calc_step(val, min, scram)
  local b, c = compare(burn_new, (burn_now + s))

  return b, c
end

local coolant_last = r_coolant()
local function coolant_controll(burn_now, burn_new, con, cb)
  local min = 60
  local scram = 10
  local cond = "cool"

  local b, c  = calc_burn(r_coolant(), min, scram, burn_new, burn_now)
  con = make_con(con, cond, c)
  
  local can_burn = can_set_burn(r_coolant() , coolant_last, min, cb)
  coolant_last = r_coolant()
  
  return b, con, can_burn
end

local temp_last = r_temp()
local function temp_controll(burn_now, burn_new, con, cb)
  local min = 500
  local scram = 900
  local safe = 50
  local cond = "tmp"

  local b, c  = calc_burn(r_temp(), min, scram, burn_new, burn_now)
  con = make_con(con, cond, c)

  local can_burn = can_set_burn(r_temp() , temp_last, min, cb)
  temp_last = r_temp()
  
  return b, con, can_burn
end

local water_last = b_water()
local function water_controll(burn_now, burn_new, con, cb)
  local min = 60
  local scram = 40
  local cond = "wat"
  
  local b, c  = calc_burn(b_water(), min, scram, burn_new, burn_now)
  con = make_con(con, cond, c)

  local can_burn = can_set_burn(b_water() , water_last, min, cb)
  water_last = b_water()
  
  return b, con, can_burn
end

local function reac_controll()
  local burn = round(r_burn(),2)
  local con = ""
  local b = burn + r_burn_step_max
  local cb = true

  --reactor----
  b, con, cb = coolant_controll(burn, b, con, cb) --coolant
  --b, con, cb = temp_controll(burn, b, con, cb) --temp
  --boiler----
  b, con, cb = water_controll(burn, b, con, cb) --water

  if undo == true then  --undo
    if undo_pos >= undo_lim then  
      cb = true
      b = (r_burn()-undo_step)
      log((b - burn), b, "undo", cb)  --undo log
    end
  end
  if b > burn then  --time interval
    interval = interval_inc
  elseif b < burn and cb == true then
    interval = interval_dec
  else
    interval = interval_inc
  end
  --set burn rate
  if cb == true then  --can burn
    r_set_burn(b)
    undo_pos = 0
  else
    undo_pos = undo_pos + 1
  end
  log((b - burn), b, con, cb)  --log
end
--main loop
while true do
  if r_status() then
    reac_controll()
  end

  sleep(interval)
end
