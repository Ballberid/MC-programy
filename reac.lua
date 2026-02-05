local reac = peripheral.wrap("fissionReactorLogicAdapter_1")
local boil = peripheral.wrap("boilerValve_0")
local turb = peripheral.wrap("turbineValve_0")
local mon = peripheral.wrap("monitor_3")

local interval = 0.1  --refresh interval
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

local function log(step, burn, cond)
  step = round(step,2)
  burn = round(burn,2)
  print("step: " .. step .. " | burn: " .. burn .. " | " .. cond)
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
  mon.write("step: " .. step .. " | burn: " .. burn .. " | " .. cond)
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
  if x > lim then
    step = map(x, lim, safe, r_burn_step_min, r_burn_step_max)
    step = round(step, 2)
  else
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

local function r_set_burn(burn)
  burn = clamp(burn, 0, 1920)
  burn = round(burn, 2)
  reac.setBurnRate(burn)
end

local function coolant_controll(burn_now, burn_new, con)
  local min = 40
  local scram = 10
  local cond = "cool"
  
  local s = calc_step(r_coolant(), min, scram)
  local b, c = compare(burn_new, (burn_now + s))
  con = make_con(con, cond, c)

  return b, con
end
local function temp_controll(burn_now, burn_new, con)
  local min = 500
  local scram = 900
  local safe = 50
  local cond = "tmp"
  
  local s = calc_step(r_temp(), min, scram, safe)
  s = map(s, r_burn_step_min, r_burn_step_max, r_burn_step_max, r_burn_step_min)
  s = s*(-1)
  local b, c = compare(burn_new, (burn_now + s))
  con = make_con(con, cond, c)

  return b, con
end
local function water_controll(burn_now, burn_new, con)
  local min = 60
  local scram = 40
  local cond = "wat"
  
  local s = calc_step(b_water(), min, scram)
  local b, c = compare(burn_new, (burn_now + s))
  con = make_con(con, cond, c)

  return b, con
end

local function reac_controll()
  local burn = round(r_burn(),2)
  local con = ""
  local b = burn + r_burn_step_max

  --reactor----
  b, con = coolant_controll(burn, b, con) --coolant
  --b, con = temp_controll(burn, b, con) --temp
  --boiler----
  --b, con = water_controll(burn, b, con) --water

  
  --set burn rate
  --r_set_burn(b)
  log((b - burn), b, con)
end
--main loop
local function main()
  if r_status() then
    reac_controll()
  end
  
  sleep(interval)
end

--zaciatok loopu
while true do
  local ok, err = pcall(main)

  if not ok then
    print("CHYBA:", err)
    print("Restart za 3s...")
    sleep(3)
    os.reboot()
  end
end
