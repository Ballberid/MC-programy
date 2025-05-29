local compressor = peripheral.wrap("back")
local output = false
local mon = peripheral.wrap("top")
mon.setTextScale(0.5)
mon.setCursorPos(1,3)
mon.clear()

if not compressor then
  print("Compressor nie je pripojeny!")
end

function round2(num)
  return math.floor(num * 100 + 0.5) / 100
end

while true do
  local pressure = compressor.getPressure()
  local press = round2(pressure)
  mon.clear()
  mon.setCursorPos(1,3)
  mon.write("press:")
  mon.setCursorPos(7,3)
  mon.write(press)

  if pressure < 18 and output == false then
    redstone.setOutput("left", true)
    output = true
    print("Tlak pod 18 bar -> zapinam vystup")
  elseif pressure > 19 and output == true then
    redstone.setOutput("left", false)
    output = false
    print("Tlak nad 19 bar -> vypinam vystup")
  end

  sleep(1)
end
