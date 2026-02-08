local reac = peripheral.wrap("fissionReactorLogicAdapter_3")
local boil = peripheral.wrap("boilerValve_1")

local reac_side = "left"
local boil_side = "right"

local reac_ok = 100
local reac_nok = 10
local boil_ok = 40
local boil_nok = 60
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
  if reac_cool() <= reac_nok then
    redstone.setOutput(reac_side, true)
  else
    redstone.setOutput(reac_side, false)
  end
end
local function check_boil()
  if boil_cool() > boil_nok then
    redstone.setOutput(boil_side, true)
  elseif boil_cool() < boil_ok then
    redstone.setOutput(boil_side, false)
  end
end
--hlavny kod
redstone.setOutput(reac_side, false)
redstone.setOutpus(boil_side, false)

while true do
end
