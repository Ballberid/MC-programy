local sprava = " "

sprava = "refuel"  shell.run("send.lua", sprava)
sprava = "tLeft"  shell.run("send.lua", sprava)
turtle.turnLeft()

for i=1, 16 do
  turtle.select(i)
  local item = turtle.getItemDetail(i)
  if item == nill then
    sprava = "emp.pos:"..i  shell.run("send.lua", sprava)
    break
  end
  if i == 16 and item ~= nill then
    sprava = "no emp.pos"  shell.run("send.lua", sprava)
    sprava = "tRight"  shell.run("send.lua", sprava)
    turtle.turnRight()
    shell.run("unload.lua")
  end
end
