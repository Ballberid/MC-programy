local sprava = " "
local fuel1 = "minecraft:coal"
local fuel2 = "minecraft:charcoal"

sprava = "refuel"  shell.run("send.lua", sprava)

function FindEmptyPos()
  sprava = "fn:emp.pos"  shell.run("send.lua", sprava)
  for i=1, 16 do
    turtle.select(i)
    local item = turtle.getItemDetail(i)
    if item == nill then
      sprava = "emp.pos:"..i  shell.run("send.lua", sprava)
      break
    end
    if i == 16 and item ~= nill then
      sprava = "no.emp.pos"  shell.run("send.lua", sprava)
      sprava = "tRight"  shell.run("send.lua", sprava)
      turtle.turnRight()
      sprava = "try.unload"  shell.run("send.lua", sprava)
      shell.run("unload.lua")
      sprava = "tLeft"  shell.run("send.lua", sprava)
      turtle.turnLeft()
      sprava = "try.refuel"  shell.run("send.lua", sprava)
      FindEmptyPos()
      return
    end
  end
end

function GetFuel()
  sprava = "fn:gt.fuel"  shell.run("send.lua", sprava)
  local select_item = turtle.getItemDetail()
  if select_item == nill then
    sprava = "tSuck"  shell.run("send.lua", sprava)
    turtle.suck()
    select_item = turtle.getItemDetail()
    if select_item and select_item.name ~= fuel1 or select_item == nill then
      if select_item and select_item.name ~= fuel2 or select_item == nill then
        sprava = "fl.not.find"  shell.run("send.lua", sprava)
        local answer = " "
        while answer ~= "ano" do
            print("Prosim doplnte palivo do truhly a potvrdte /ano/")
            answer = read()
            if answer == "ano" then
              sprava = "/ano/tSuck"  shell.run("send.lua", sprava)
              turtle.suck()
              GetFuel()
              return
            else
              print("Nespravna odpoved")
          end
        end
      end
    end
  end
  if select_item and select_item.name == fuel1 or select_item and select_item.name == fuel2 then
    sprava = "find.fl."  shell.run("send.lua", sprava)
    sprava = "tRight"  shell.run("send.lua", sprava)
    turtle.turnRight()
    turtle.refuel(20)
  else
    sprava = "bad.fl."  shell.run("send.lua", sprava)
    FindEmptyPos()
    GetFuel()
    return
  end
end

sprava = "tLeft"  shell.run("send.lua", sprava)
turtle.turnLeft()

FindEmptyPos()
GetFuel()
