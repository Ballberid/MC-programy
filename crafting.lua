local chest = peripheral.wrap("right")


local item_data = {
  { name = "mekanism:basic_induction_cell", side = "left", type = 1, amount = 0},
}

local function check_amount(name)
  local amount = 0
  
  for _, item in pairs(chest.list()) do
    if name ~= nil then
      if item.name == name then
        amount = amount + item.count
      end
    else
      amount = amount + item.count
    end
  end

  return amount
end

--loop
for i, data in ipairs(table) do
  if data.type == 1 then
    data.amount = check_amount(data.name)
  end
  print(data.amount)
end


--[[
redstone.setOutput("back", false)
redstone.setOutput("left", false)
redstone.setOutput("front", false)

term.clear()
term.setCursorPos(1,1)
print("Kolko treba vyrobit?")
term.setCursorPos(1,2)
print("Pocet: ")
term.setCursorPos(10,2)
local input = tonumber(read())

redstone.setOutput("back", true)

term.setCursorPos(1,3)
print("Vyrobene: ")
while true do
  local amount = 0

  for _, item in pairs(chest.list()) do
    amount = amount + item.count
  end

  term.setCursorPos(13,3)
  print(amount)

  sleep(0,5)
  if amount >= input then
    redstone.setOutput("back", false)
    term.setCursorPos(1,4)
    print("Vyroba dokoncena.")
    break
  end
end

local fin = read()
term.clear()
shell.run("test")
]]
