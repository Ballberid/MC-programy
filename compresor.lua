local compressor = peripheral.fing(pneumaticcraft:advanced_liquid_compressor) -- uprav podľa umiestnenia

if not compressor then
  error("Compressor nie je pripojeny!")
end

while true do
  local pressure = compressor.getPressure()

  if pressure < 18 then
    redstone.setOutput("down", true)
    print("Tlak pod 18 bar – zapinam vxstup")
  elseif pressure > 19 then
    redstone.setOutput("down", false)
    print("Tlak nad 19 bar – vypinam vystup")
  end

  sleep(1)  -- čakaj 1 sekundu
end
