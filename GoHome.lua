local x, y, z = ...
local sprava = " "

sprava = "GoHome"  shell.run("send.lua", sprava)
sprava = "x:"..x.."/y:"..y.."/z:"..z  shell.run("send.lua", sprava)

for ix=1, x do
  sprava = "ix:"..ix.."/back"  shell.run("send.lua", sprava)
  turtle.back()
end

sprava = "tLeft"  shell.run("send.lua", sprava)
turtle.turnLeft()

for iy=1, y do
  sprava = "iy:"..iy.."/forw"  shell.run("send.lua", sprava)
  turtle.forward()
end

sprava = "tRight"  shell.run("send.lua", sprava)
turtle.turnRight()

for iz=1, z do
  sprava = "iz:"..iz.."/down"  shell.run("send.lua", sprava)
  turtle.down()
end

sprava = "HomePos"  shell.run("send.lua", sprava)
