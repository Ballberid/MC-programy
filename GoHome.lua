local x, y, z = ...
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
