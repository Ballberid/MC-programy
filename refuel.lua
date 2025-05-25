local sprava = " "

turtle.turnLeft()

for i=1, 16 do
  turtle.select(i)
  local item = turtle.getItemDetail(i)
  if item == nill then
    break
  end
  if i == 16 and item ~= nill then
    turtle.turnRight()
    shell.run("unload.lua")
  end
end
