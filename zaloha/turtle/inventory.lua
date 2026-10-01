local inv = {}

function inv.freeSlots()
  local freeSlots = 0
  
  for slot = 1, 16 do
    if turtle.getItemCount(slot) == 0 then
      freeSlots = freeSlots + 1
    end
  end

  return freeSlots
end

return inv
