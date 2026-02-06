local chest = peripheral.wrap("right")

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
