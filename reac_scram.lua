local reac = peripheral.wrap("fissionReactorLogicAdapter_1")
local boil = peripheral.wrap("boilerValve_0")
local turb = peripheral.wrap("turbineValve_0")

local interval = 0.1

local function main()
  while true do --loop
    
    sleep(interval)
  end
end

--zaciatok kodu

while true do
  local ok, err = pcall(main)

  if not ok then
    print("CHYBA:", err)
    print("Restart za 3s...")
    redstone.setOutput("right" true)
    sleep(3)
    os.reboot()
  end
end
