local reac = "fissionReactorLogicAdapter_1"

local function round(x)
  return math.floor(x * 1000)/1000
end

local function coolant()
  local c = reac.getCoolantFilledPercentage()
  return round(c)
end

while true do
  sleep(0.5)
end
