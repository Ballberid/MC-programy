local x, y, z = ...
local sprava = " "

sprava = "GoBack"
shell.run(send sprava)
sprava = "x:"..x.."y:"..y.."z:"..z
shell.run(send sprava)

for iz=1, z do
  turtle.down()
end

turtle.turnRight()

for iy=1, y do
  turtle.forward()
end

turtle.turnLeft()

for ix=1, x do
  turtle.forward()
end
