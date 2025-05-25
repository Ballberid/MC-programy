local sprava = " "
local fuel1 = "minecraft:coal"
local fuel2 = "minecraft:charcoal"

sprava = "unload"  shell.run("send.lua", sprava)
sprava = "tLeft"  shell.run("send.lua", sprava)
turtle.turnLeft()
sprava = "tLeft"  shell.run("send.lua", sprava)
turtle.turnLeft()

for slot=1, 16 do
  turtle.select(slot)
  local item = turtle.getItemDetail(slot)
  if item and item.name ~= fuel1 then
    if item and item.name ~= fuel2 then
      sprava = "tDrop/slot:"..slot  shell.run("send.lua", sprava)
      turtle.drop()
    end
  end
end

sprava = "uloaded"  shell.run("send.lua", sprava)
sprava = "tRight"  shell.run("send.lua", sprava)
turtle.turnRight()
sprava = "tRight"  shell.run("send.lua", sprava)
turtle.turnRight()
