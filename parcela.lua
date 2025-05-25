local sprava = " "

print("Zadaj dlzku parcely: ")
local length = read() - 1
sprava = "dlzka:"..length  shell.run("send.lua", sprava)
print("Zadaj sirku parcely: ")
local width = read()
sprava = "sirka:"..width  shell.run("send.lua", sprava)
print("Zadaj vysku parcely: ")
local heigth = read()
sprava = "vyska:"..heigth  shell.run("send.lua", sprava)

local blok = "minecraft:dirt"
local x = 0
local y = 0
local z = 0

function GoRefuel()
  sprava = "fn:GoRef."  shell.run("send.lua", sprava)
  shell.run("GoHome.lua", x, y, z)
  shell.run("refuel.lua")
  if turtle.getFuelLevel() > ((x + y + z) * 2) then
    sprava = "have.fuel"  shell.run("send.lua", sprava)
    shell.run("GoBack.lua", x, y, z)
  else
    sprava = "dont.fuel"  shell.run("send.lua", sprava)
    shell.run("refuel.lua")
    shell.run("GoBack", x, y, z)
  end
end

function FindAndRefuel()
  sprava = "fn:findFuel"  shell.run("send.lua", sprava)
  for i=1, 16 do
    local item = turtle.getItemDetail(i)
    if item and item.name == coal or item and item.name == charcoal then
      sprava = "inv.fuel"  shell.run("send.lua", sprava)
      turtle.select(i)
      turtle.refuel(20)
      break
    end
    if i == 16 then
      if item and item.name ~= coal or item and item.name ~= charcoal or item == nill then
        sprava = "inv.no.fuel"  shell.run("send.lua", sprava)
        GoRefuel()
      end
    end
  end
end

function CheckFuel()
  sprava = "fn:ck.fuel"  shell.run("send.lua", sprava)
  local dist = ((x * 2 ) + (y + z + 5))
  sprava = "dist:"..dist  shell.run("send.lua", sprava)
  if turtle.getFuelLevel() < dist then
    sprava = "low.fuel:"..turtle.getFuelLevel()  shell.run("send.lua", sprava)
    FindAndRefuel()
  end
end

function GoUnload()
  sprava = "fn:GoUnload"  shell.run("send.lua", sprava)
  shell.run("GoHome.lua", x, y, z)
  shell.run("unload.lua")
  shell.run("GoBack.lua", x, y, z)
end

function CheckIfFull()
  sprava = "fn:ck.if.full"  shell.run("send.lua", sprava)
  local item = turtle.getItemDetail()
  if item ~= nill then
    for i=1, 16 do
      turtle.select(i)
      item = turtle.getItemDetail(i)
      if item == nill then
        sprava = "not.full"  shell.run("send.lua", sprava)
        break
      end
      if i == 16 and item ~= nill then
        sprava = "inv.full"  shell.run("send.lua", sprava)
        GoUnload()
      end
    end
  end
end

for h=1, heigth do
  sprava = "for.h:"..h  shell.run("send.lua", sprava)
  z = h - 1
  sprava = "z:"..z  shell.run("send.lua", sprava)
  for w=1, width do
    sprava = "for.w:"..w  shell.run("send.lua", sprava)
    y = w -1
    sprava = "y:"..y  shell.run("send.lua", sprava)
    CheckFuel()
    CheckIfFull()
    for l=1, length do
      sprava = "for.l:"..l  shell.run("send.lua", sprava)
      x = l - 1
      sprava = "x:"..x  shell.run("send.lua", sprava)
      if turtle.detectDown() == false and h < 2 then
        sprava = "det.hole"  shell.run("send.lua", sprava)
        shell.run("fill.lua", blok)
      end
      sprava = "tDig"  shell.run("send.lua", sprava)
      turtle.dig()
      sprava = "tFor"  shell.run("send.lua", sprava)
      turtle.forward()
    end
    for lb=1, length do
      sprava = "for.lb:"..lb  shell.run("send.lua", sprava)
      x = length - (lb - 1)
      sprava = "x:"..x  shell.run("send.lua", sprava)
      sprava = "tBack"  shell.run("send.lua", sprava)
      turtle.back()
    end
    sprava = "new.line"  shell.run("send.lua", sprava)
    sprava = "tRight"  shell.run("send.lua", sprava)
    turtle.turnRight()
    sprava = "tDig"  shell.run("send.lua", sprava)
    turtle.dig()
    sprava = "tForw"  shell.run("send.lua", sprava)
    turtle.forward()
    sprava = "tLeft"  shell.run("send.lua", sprava)
    turtle.turnLeft()
  end
  sprava = "new.layer"  shell.run("send.lua", sprava)
  shell.run("GoHome.lua", x, y, 0)
  sprava = "tUp"  shell.run("send.lua", sprava)
  turtle.up()
end

sprava = "END"  shell.run("send.lua", sprava)
