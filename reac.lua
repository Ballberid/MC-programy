local reac = "fissionReactorLogicAdapter_1"

local save_temp = 300
local lim = 5
local min_coolant = 10
local max_heat_coolant = 40

local function round(x, dec)
  local m = 10^dec
  return math.floor(x * m)/m
end
local function temp()
  local t = reac.getTemperature()
  return round(t,2)
end
local function coolant()
  local c = reac.getCoolantFilledPercentage()
  return round(c,3)
end
local function heat_coolant()
  local c = reac.getHeatedCoolantFilledPercentage()
  return round(c,3)
end

local function scram_protocol()
  local scram = false
  local con = ""
  
  if coolant() <= min_coolant() then
    con = con .. "low coolant | "
    scram = true
  end
  if heat_coolant() >= max_heat_coolant() then
    con = con .. "heat coolant limit | "
    scram = true
  end

  if scram == true then
    reac.scram()
    print("Reactor bol odstaveny: " .. con)
  end

while true do
  sleep(0.5)
end
