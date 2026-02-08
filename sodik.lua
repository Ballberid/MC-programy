local reac = peripheral.wrap("fissionReactorLogicAdapter_3")
local boil = peripheral.wrap("boilerValve_1")

local reac_side = "left"
local boil_side = "right"

local reac_ok = 80
local reac_nok = 40
local boil_ok = 40
local boil_nok = 80

local interval = 0.5
--basic
local function reac_cool()
  local v = reac.getCoolantFilledPercentage()*100
  return v
end
local function boil_cool()
  local v = boil.getCooledCoolantFilledPercentage()*100
  return v
end
--methods
local function check_reac()
  local msg = ""
  if reac_cool() <= reac_nok then
    redstone.setOutput(reac_side, true)
    msg = "reac nok"
  elseif reac_cool() >= reac_ok then
    redstone.setOutput(reac_side, false)
    msg = "reac ok"
  end
  return msg
end
local function check_boil()
  local msg = ""
  if boil_cool() > boil_nok then
    redstone.setOutput(boil_side, true)
    msg = "boil nok"
  elseif boil_cool() < boil_ok then
    redstone.setOutput(boil_side, false)
    msg = "boil ok"
  end
  return msg
end
--hlavny kod
print(".....")
redstone.setOutput(reac_side, false)
redstone.setOutput(boil_side, false)

while true do
  local msg = check_reac()
  msg = msg .. " | " .. check_boil()
  print(msg)
  
  sleep(interval)
end
