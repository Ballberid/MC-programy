local x, y, z = ...

for ix=1, x do
  turtle.back()
end

turtle.turnLeft()

for iy=1, y do
  turtle.forward()
end

turtle.turnRight()

for iz=1, z do
  turtle.down()
end
