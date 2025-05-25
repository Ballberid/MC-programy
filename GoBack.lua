local x, y, z = ...
local sprava = " "

sprava = "GoBack"  shell.run("send.lua", sprava)
sprava = "x:"..x.."/y:"..y.."/z:"..z  shell.run("send.lua", sprava)

for iz=1, z do
  sprava = "iz:"..iz.."/down"  shell.run("send.lua", sprava)
  turtle.down()
end

sprava = "tRight"  shell.run("send.lua", sprava)
turtle.turnRight()

for iy=1, y do
  sprava = "iy:"..iy.."/forw"  shell.run("send.lua", sprava)
  turtle.forward()
end

sprava = "tLeft"  shell.run("send.lua", sprava)
turtle.turnLeft()

for ix=1, x do
  sprava = "ix:"..ix.."/forw"  shell.run("send.lua", sprava)
  turtle.forward()
end

sprava = "WorkPos"  shell.run("send.lua", sprava)
