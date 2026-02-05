local reac = peripheral.wrap("fissionReactorLogicAdapter_1")
local boil = peripheral.wrap("boilerValve_0")
local turb = peripheral.wrap("turbineValve_0")

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
  elseif x < lim then
    step = map(x, lim, scram, r_burn_step_min, r_burn_step_max)
    step = step*(-1)
  end
  return step
end

local function compare(burn1, burn2)
  local burn = 0
  if burn1 < burn2 then
    burn = burn1
  else
    burn = burn2
  end
  return burn
end

local function r_set_burn(burn)
  burn = clamp(burn, 0, 1920)
  reac.setBurnRate(burn)
end

local function log(step, burn, cond)
  print("step: " .. step .. " | burn: " .. burn .. " | " .. cond)
end

local function reac_controll()
  local burn = r_burn()
  if burn == 0 then
    burn = 0.5
  end
  local s = 0

  --reactor----
  --coolant
  s = calc_step(r_coolant(), r_coolant_min, r_coolant_scram)
  log(s, (burn + s), "cool")
  burn = burn + s
  --temp
  --s = calc_step(r_temp(), r_temp_min, r_temp_scram)
  --log(s, (burn + s), "temp")
  --burn = compare(burn, (burn + s))
  --boiler----
  --water
  s = calc_step(b_water(), b_water_min, b_water_scram)
  log(s, (burn + s), "wat")
  burn = compare(burn, (burn + s))

  --set burn rate
  r_set_burn(burn)
  log((burn - r_burn()), burn, "fin")
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
