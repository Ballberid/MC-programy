local reac = peripheral.wrap("fissionReactorLogicAdapter_1")
local boil = peripheral.wrap("boilerValve_0")
local turb = peripheral.wrap("turbineValve_0")

local interval = 0.1  --refresh interval
--reactor
local r_temp_min = 300  --target temp
local r_temp_scram = 900
local r_coolant_min = 40  --minimalna hodnota sodiku
local r_coolant_scram = 10
local r_burn_step = 1 --velkost kroku nastavenia burn
local r_burn_step_max = 2
local r_burn_step_min = 0.1
--boiler
local b_water_min = 60  --minimalna hodnota vody
local b_water_scram = 40

term.clear()

--basic function
local function clamp(x, min, max)
  if x < min then return min end
  if x > max then return max end
  return x
end
local function map(x, inMin, inMax, outMin, outMax)
  if inMax == inMin then return outMin end
  local v = (x - inMin) * (outMax - outMin) / (inMax - inMin) + outMin
  return clamp(v, outMin, outMax)
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
    cond = true
  elseif x < lim then
    step = map(x, lim, scram, r_burn_step_min, r_burn_step_max)
    cond = false
  end
  return step, cond
end
local function compare(in_step, in_dir, s, d)
  local step = 0
  local dir = false
  
  if d == true and in_dir == true then
    if s < in_step then
      step = s
    end
  elseif d == false and in_dir == true then
    step = s
    dir = d
  elseif d == false and in_dir == false then
    if s > in_step then
      step = s
    end
  end
  return step, dir
end

local function r_set_burn(step, dir)
  local rate = 0
  if dir == true then
    rate = r_burn() + step
  elseif dir == false then
    rate = r_burn() - step
  end

  rate = clamp(rate, 0, 1920)
  reac.setBurnRate(rate)
end

local function reac_controll()
  local step = 0
  local dir = true
  local s = 0
  local d = true

  --reactor----
  --coolant
  s, d = calc_step(r_coolant(), r_coolant_min, r_coolant_scram)
  step, dir = compare(step, dir, s, d)
  --temp
  s, d = calc_step(r_temp(), r_temp_min, r_temp_scram)
  step, dir = compare(step, dir, s, d)
  --boiler----
  --water
  s, d = calc_step(b_water(), b_water_min, b_water_scram)
  step, dir = compare(step, dir, s, d)

  --set burn rate
  r_set_burn(step, dir)
  print("step: " .. step .. " | dir: " .. dir)
end
--main loop
local function main()
  if r_status() then
    reac_controll()
  end
  
  sleep(interval)
end

--zaciatok loopu
main()
