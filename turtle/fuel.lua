local fl = {}

function fl.refuel()
  local fuel = turtle.getFuelLevel()
  
  for slot = 1, 16 do
    turtle.select(slot)
    if turtle.refuel(0) then
      turtle.refuel(64)
      fuel = turtle.getFuelLevel()
    end
  end
  
  return fuel
end



return fl
