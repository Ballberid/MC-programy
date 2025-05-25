local block = ...
local sprava = " "

sprava = "fill"  shell.run("send.lua", sprava)

for i=1, 16 do
  local item = turtle.getItemDetail(i)
  if item and item.name == block then
    turtle.select(i)
    sprava = "place"  shell.run("send.lua", sprava)
    turtle.placeDown()
    break
  else
    sprava = "empty"  shell.run("send.lua", sprava)
  end
end
