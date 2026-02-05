local reac = peripheral.wrap("fissionReactorLogicAdapter_1")
local boil = peripheral.wrap("boilerValve_0")
local turb = peripheral.wrap("turbineValve_0")
local mon = peripheral.wrap("monitor_1")

local interval = 1  --refresh interval
--reactor
local r_temp_min = 300  --target temp
local r_temp_scram = 900
local r_coolant_min = 40  --minimalna hodnota sodiku
local r_coolant_scram = 10
local r_burn_step = 1 --velkost kroku nastavenia burn
local r_burn_step_max = 2
local r_burn_step_min = 0.01
--boiler
local b_water_min = 60  --minimalna hodnota vody
local b_water_scram = 40

mon.clear()
mon.setCursorPos(1,1)
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
  print("step: " .. step .. " | burn: " .. burn .. " | " .. cond)
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
local function calc_step(x, lim, scram)
  local step = 0
  local cond = false
  if x > lim then
    step = map(x, lim, 100, r_burn_step_min, r_burn_step_max)
  elseif x < lim then
    step = map(x, lim, scram, r_burn_step_min, r_burn_step_max)
    step = step*(-1)
  end
  local result = clamp(step, r_burn_step_min, r_burn_step_max)
  return round(result, 2)
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

local function reac_controll()
  local burn = r_burn()
  local con = ""
  local c = 0
  local b = burn + r_burn_step_max
  local s = 0

  --reactor----
  --coolant
  s = calc_step(r_coolant(), r_coolant_min, r_coolant_scram)
  b, c = compare(b, (burn + s))
  local cond_cool = "cool"
  con = make_con(con, cond_cool, c)
  --temp
  s = calc_step(r_temp(), r_temp_min, r_temp_scram)
  s = map(s, r_burn_step_min, r_burn_step_max, r_burn_step_max, r_burn_step_min)
  b, c = compare(b, (burn + s))
  local cond_temp = "tmp"
  con = make_con(con, cond_temp, c)
  --boiler----
  --water
  s = calc_step(b_water(), b_water_min, b_water_scram)
  b, c = compare(b, (burn + s))
  local cond_water = "wat"
  con = make_con(con, cond_water, c)
  --set burn rate
  r_set_burn(b)
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
