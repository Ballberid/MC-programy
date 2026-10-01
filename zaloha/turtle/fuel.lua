local fl = {}

function fl.refuel()
  local fuel = turtle.getFuelLevel()
  local currentSlot = turtle.getSelectedSlot()
  
  for slot = 1, 16 do
    turtle.select(slot)
    if turtle.refuel(0) then
      turtle.refuel(64)
      fuel = turtle.getFuelLevel()
    end
  end

  turtle.select(currentSlot)
  return fuel
end



return fl
