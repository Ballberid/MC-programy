local reac = peripheral.wrap("fissionReactorLogicAdapter_1")
local boil = peripheral.wrap("boilerValve_0")
local turb = peripheral.wrap("turbineValve_0")
local printer = peripheral.wrap("left")

local printer_active = true
local page_size = 20
local page_pos = 1

local interval = 0.1
print("Scram rdy")
--reactor
local r_temp_max = 900
local r_coolant_min = 10
local r_heated_max = 40
local r_waste_max = 50
local r_fuel_min = 5
local r_temp_rev = 300
local r_coolant_rev = 100
local r_heated_rev = 5
local r_waste_rev = 10
--boiler
local b_water_min = 40
local b_heated_max = 50
local b_steam_max = 50
local b_water_rev = 100
local b_steam_rev = 5
--turbina
local t_energy_max = 80
local t_energy_rev = 5

local function print_page(text)
  if printer.getInkLevel() <= 0 or printer.getPaperLevel() <= 0 then
    print("Neni farba alebo papier!")
    return
  end
  printer.setCursorPos(1,page_pos)
  printer.write(text)
  page_pos = page_pos + 1

  if page_pos >= page_size then
    printer.endPage()
    printer.newPage()
    page_pos = 1
  end
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
local function b_steam()
  return boil.getSteamFilledPercentage()*100
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
  if b_steam() >= b_steam_max then
    con = con .. "b.steam" .. " | "
    scram = true
  end
  --turb
  if t_energy() >= t_energy_max then
    con = con .. "t.energy" .. " | "
    scram = true
  end
  --scram
  if scram == true then
    reac.scram()
    local text = "Reactor bol odstaveny: " .. con
    print(text)
    if printer_active == true then
      print_page(text)
    end
  end
end

local function revive_protocol()
local revive = true
  --reactor
  if r_temp() > r_temp_rev then
    revive = false
  end
  if r_coolant() > r_coolant_rev then
    revive = false
  end
  if r_heated() > r_heated_rev then
    revive = false
  end
  if r_waste() > r_waste_rev then
    revive = false
  end
  --boiler
  if b_water() > b_water_rev then
    revive = false
  end
  if b_steam() > b_steam_rev then
    revive = false
  end
  --turbina
  if t_energy() > t_energy_rev then
    revive = false
  end

  if revive == true then
    reac.setBurnRate(10)
    reac.activate()
    local text = "Aktivacia reaktoru"
    print(text)
    if printer_active == true then
      print_page(text)
    end
  end
end

local function main()
  while true do --loop
    if r_status() then
      scram_protocol()
    else
      revive_protocol()
    end
    sleep(interval)
  end
end

--zaciatok kodu
if printer_active == true then
  printer.newPage()
end

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
