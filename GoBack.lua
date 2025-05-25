local x, y, z = ...

for iz=1, z do
  turtle.down()
end

turtle.turnRight()

for iy=1, y do
  turtle.forward()
end

turtle.turnLeft()

for ix=1, x do
  turtle.back()
end
