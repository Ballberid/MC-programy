local compressor = peripheral.wrap("back")

if not compressor then
  print("Compressor nie je pripojeny!")
end

while true do
  local pressure = compressor.getPressure()

  if pressure < 18 then
    redstone.setOutput("left", true)
    print("Tlak pod 18 bar – zapinam vystup")
  elseif pressure > 19 then
    redstone.setOutput("left", false)
    print("Tlak nad 19 bar – vypinam vystup")
  end

  sleep(1)
end
