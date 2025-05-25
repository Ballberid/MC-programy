rednet.open("left")
local ciel_id = 2
local sprava = " "
function send(text)
  rednet.send(ciel_id,text)
  rednet.send(3,text)
end

local sleepTime = 3
function sleep()
  os.sleep(sleepTime)
end

print("Zadaj dlzku parcely: ")
local dlzka = read()-1
send("dlzka "..dlzka)
print("Zadaj sirku parcely: ")
local sirka = read()
send("sirka"..sirka)
print("Zadaj vysku parcely: ")
local vyska = read()
send("vyska "..vyska)

local dirt = "minecraft:dirt"
local coal = "minecraft:coal"
local charcoal = "minecraft:charcoal"
local hladany_blok = dirt
local smer = "vpred"
local dx = 0
local sx = 0
local vx = 0

function findDirt()
  send("fn:findDirt")
  for i=1, 16 do
    local item = turtle.getItemDetail(i)
    if item and item.name == hladany_blok then
      turtle.select(i)
      send("slot:"..i)
      send("break")
      break
    end
  end
end

function GoRefuel()
  send("fn:GoRefuel")
  send("HOME")
  send(dx..","..sx..","..vx..","..smer)
  GoHome(dx,sx,vx,smer)
  send("Vyloz")
  Vylozit()
  send("Zober Pal.")
  ZoberPalivo()
  send("Back")
  send(dx..","..sx..","..vx..","..smer)
  GoBack(dx,sx,vx,smer)
end

function ZoberPalivo()
  send("fn:ZoberPal.")
  turtle.turnLeft()
  sleep()
  turtle.select(1)
  turtle.suck()
  turtle.turnRight()
  sleep()
end

function FindAndRefuel()
  send("fn:Refuel")
  for i=1, 16 do
    local item = turtle.getItemDetail(i)
    if item and item.name == coal or item and item.name == charcoal then
      turtle.select(i)
      turtle.refuel(10)
      send("refuel")
      send("break")
      break
    end
    if i == 16 then
      if item and item.name ~= coal or item and item.name ~= charcoal or item == nill then
        print("Neni palivo!!!")
        send("Neni palivo")
        send("GoRefuel")
        GoRefuel()
      end
    end
  end
end

function KontrolaPaliva(dx,sx,vx,smer)
  local vzdialenost = (dx+sx+vx)+5
  send("fn:kon.pal.")
  send("dis:"..vzdialenost)
  if turtle.getFuelLevel() < vzdialenost then
    print("Malo paliva")
    send("Malo paliva")
    send("FindAndRefuel")
    FindAndRefuel()
  else
  end
end

function GoHome(dx,sx,vx,smer)
  send("fn:GoHome")
  send(dx..","..sx..","..vx..","..smer)
  if vx >= 1 then
    send("vx>1 vx:"..vx)
    for i=1, vx do
      send("v:"..i.." down")
      turtle.down()
      sleep()
    end
  end
  if smer == "vpred" then
    send("if:vpred:"..smer)
    for i=1, dx do
      send("d:"..i.." back")
      turtle.back()
      sleep()
    end
    if sx > 1 then
      send("sx>1 turnLeft")
      turtle.turnLeft()
      sleep()
      fort i=1, sx do
        send("s:"..i.." forw")
        turtle.forward()
        sleep()
      end
      send("turnRight")
      turtle.turnRight()
      sleep()
    end
  elseif smer == "vzad" then
    send("elif:vzad:"..smer)
    send("turnRight")
    turtle.turnRight()
    sleep()
    for i=1, sx do
      send("s:"..i.." forw")
      turtle.forward()
      sleep()
    end
    send("turnLeft")
    turtle.turnLeft()
    sleep()
    for i=1, dx do
      send("d:"..i.." forw")
      turtle.forward()
      sleep()
    end
    send("ot.180")
    turtle.turnRight()
    sleep()
    turtle.turnRight()
    sleep()
  end
end

function Vylozit()
  send("fn:Vylozit")
  send("ot.180")
  turtle.turnLeft()
  sleep()
  turtle.turnLeft()
  sleep()
  for slot=1, 16 do
    turtle.select(slot)
    local item = turtle.getItemDetail(slot)
    if item and item.name ~= coal then
      if item and item.name ~= charcoal then
        turtle.drop()
      end
    end
  end
  send("vylozene")
  send("ot.180")
  turtle.turnLeft()
  sleep()
  turtle.turnLeft()
  sleep()
end

function KontrolaPlnosti()
  send("fn:kon.pln.")
  for i=1, 16 do
    if turtle.select(i) == nill then
      break
    elseif i == 16 and turtle.select(i) ~= nill then
      send("inv.fuel:0")
      send("HOME")
      send(dx..","..sx..","..vx..","..smer)
      GoHome(dx,sx,vx,smer)
      send("Vylozit")
      Vylozit()
      send("Back")
      send(dx..","..sx..","..vx..","..smer)
      GoBack(dx,sx,vx,smer)
    end
  end
end

function GoBack(dx,sx,vx,smer)
  send("fn:GoBack")
  send(dx..","..sx..","..vx..","..smer)
  if vx >= 1 then
    send("vx>1 vx:"..vx)
    for i=1, vx do
      send("v:"..i..i" up")
      turtle.up()
      sleep()
    end
  end
  if smer == "vpred" then
    send("if:vpred:"..smer)
    send("turnRight")
    turtle.turnRight()
    sleep()
    for i=1, sx do
      send("s:"..i.." forw")
      turtle.forward()
      sleep()
    end
    send("turnLeft")
    turtle.turnLeft()
    sleep()
    for i=1, dx do
      send("d:"..i.." forw")
      turtle.forward()
      sleep()
    end
  elseif smer == "vzad" then
    send("elif:vzad:"..smer)
    for i=1, dx do
      send("d:"..i.." forw")
      turtle.forward()
      sleep()
    end
    send("turnRight")
    turtle.turnRight()
    sleep()
    for i=1, sx do
      send("s:"..i.." forw")
      turtle.forward()
      sleep()
    end
    send("turnRight")
    trutle.turnRight()
    sleep()
  end
end

FindAndRefuel()
for v=1, vyska do
  vx = v - 1
  send("for vyska")
  send("vx "..vx)
  for s=1, sirka do
    sx = s - 1
    send("for sirka")
    send("sx "..sx)
    for d=1, dlzka do
      send("for dlzka"..smer)
      if smer == "vpred" then
        dx = d-1
        send("(if)smer :"..smer)
        send("dx "..dx)
      elseif smer == "vzad" then
        dx = dlzka-(d-1)
        send("(elif)smer :"..smer)
      end
      send("kon.pal.:")
      send(dx..","..sx..","..vx..","..smer)
      KontrolaPaliva(dx,sx,vx,smer)
      send("kon.pln.")
      KontrolaPlnosti()
      if turtle.detectDown() == false and v < 2 then
        send("diera")
        send("findDirt")
        findDirt()
        turtle.placeDown()
        send("place dirt")
      end
      send("dig")
      turtle.dig()
      send("forward")
      turtle.forward()
      sleep()
    end
    send("kon.pal.")
    send(dx..","..sx..","..vx..","..smer)
    KontrolaPaliva(dx,sx,vx,smer)
    send("kon.pln.")
    KontrolaPlnosti()
    if smer == "vpred" then
      send("otocka")
      send("smer: "..smer)
      turtle.turnRight()
      sleep()
      turtle.dig()
      turtle.forward()
      sleep()
      turtle.turnRight()
      sleep()
      smer = "vzad"
      send("zmena smeru")
      send(smer)
    elseif smer == "vzad" then
      send("otocka")
      send("smer: "..smer)
      turtle.turnLeft()
      sleep()
      turtle.dig()
      turtle.forward()
      sleep()
      turtle.turnLeft()
      sleep()
      smer = "vpred"
      send("zmena smeru")
      send(smer)
    end
  end
  if v > 1 then
    send("v>1:"..v)
    send("HOME:")
    send(dx..","..sx..","..vx..","..smer)
    Gohome(dx,sx,0,smer)
    turtle.up()
    sleep()
    send("up")
  end
end
send("cykl.END")
send("HOME:")
send(dx..","..sx..","..vx..","..smer)
GoHome(dx,sx,vx,smer)
