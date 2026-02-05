local function round(x, dec)
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

----------------------------
