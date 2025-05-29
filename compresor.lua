local compressor = peripheral.wrap("back")
local output = false
local mon = peripheral.wrap("top")
mon.setTextScale(1)
mon.setCursor(1,3)
mon.clear()

if not compressor then
  print("Compressor nie je pripojeny!")
end

while true do
  local pressure = compressor.getPressure()
  mon.clear()
  mon.write(pressure)

  if pressure < 18 and output == false then
    redstone.setOutput("left", true)
    output = true
    print("Tlak pod 18 bar -> zapinam vystup")
  elseif pressure > 19 then
    redstone.setOutput("left", false)
    output = false
    print("Tlak nad 19 bar -> vypinam vystup")
  end

  sleep(1)
end
