local reac = peripheral.wrap("fissionReactorLogicAdapter_1")
local boil = peripheral.wrap("boilerValve_0")
local turb = peripheral.wrap("turbineValve_0")

local interval = 0.1
--reactor
local r_temp_max = 900
local r_coolant_min = 10
local r_heated_max = 40
local r_waste_max = 50
local r_fuel_min = 5
--boiler
local b_water_min = 40
local b_heated_max = 50
local b_steam_max = 70
--turbina
local t_energy_max = 80

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
local function r_heated()  --mnozstvo horuceho sodiku v %
  return reac.getHeatedCoolantFilledPercentage()*100
end
local function r_waste()  --mnozstvo waste
  return reac.getWasteFilledPercentage()*100
end
local function r_fuel()  --mnozstvo paliva
  return reac.getFuelFilledPercentage()*100
end
--boiler
local function b_water()
  return boil.getWaterFilledPercentage()*100
end
--turbina
local function t_energy()
  return turb.getEnergyFilledPercentage()*100
end

--protocoly
local function scram_protocol()
  local con = ""
  local scram = false
  --reac
  if r_temp() > r_temp_max then
    con = con .. "r.temp" .. " | "
    scram = true
  end
  if r_coolant() <= r_coolant_min then  --malo coolantu
    con = con .. "r.coolant" .. " | "
    scram = true
  end
  if r_heated() >= r_heated_max then  --vela heat coolantu
    con = con .. "r.heated" .. " | "
    scram = true
  end
  if r_waste() >= r_waste_max then
    con = con .. "r.waste" .. " | "
    scram = true
  end
  if r_fuel() <= r_fuel_min then
    con = con .. "r.fuel" .. " | "
    scram = true
  end
  --boil
  if b_water() <= b_water_min then
    con = con .. "b.water" .. " | "
    scram = true
  end
  --scram
  if scram == true then
    reac.scram()
    print("Reactor bol odstaveny: " .. con)
  end
end

local function main()
  while true do --loop
    if r_status() then
      scram_protocol()
    end
    sleep(interval)
  end
end

--zaciatok kodu

while true do
  local ok, err = pcall(main)

  if not ok then
    print("CHYBA:", err)
    print("Restart za 3s...")
    --redstone.setOutput("right", true)
    sleep(3)
    os.reboot()
  end
end
