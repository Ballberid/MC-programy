local compressor = peripheral.wrap("right") -- uprav podľa umiestnenia

if not compressor then
  error("Compressor nie je pripojený!")
end

while true do
  local pressure = compressor.getPressure()

  if pressure < 18 then
    redstone.setOutput("down", true)
    print("Tlak pod 18 bar – zapínam výstup")
  elseif pressure > 19 then
    redstone.setOutput("down", false)
    print("Tlak nad 19 bar – vypínam výstup")
  end

  sleep(1)  -- čakaj 1 sekundu
end
