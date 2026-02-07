local chest_side = "right"
local chest = peripheral.wrap(chest_side)
local need_setup = true

local item_data = {
  { name = "mekanism:basic_induction_cell", side = "left", type = 1, target = 30, amount = 0, active = true},
  { name = "mekanism:basic_induction_provider", side = "back", type = 1, target = 30, amount = 0, active = true},
  { name = "", side = "front", type = 2, target = 30, amount = 0, active = true},
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
local function check_production()
  local active = false
  for i, data in ipairs(item_data) do
    if (data.type == 1 or data.type == 3) and active == false then
      if data.active == true then
        active = true
      end
    end
  end
  return active
end
local function set_active(data)
  if data.amount >= data.target then
    data.active = false
  else
    data.active = true
  end
end
local function set_redstone(data)
  if data.active == true then
    redstone.setOutput(data.side, true)
  else
    redstone.setOutput(data.side, false)
  end
end
-------------------------------------
local function logic()
  for i, data in ipairs(item_data) do
    if data.type == 0 then
      
    elseif data.type == 1 then
      data.amount = check_amount(data.name)
      set_active(data)
      set_redstone(data)
    elseif data.type == 2 then
      if check_production() == false then
        data.active = false
      end
      set_redstone(data)
    elseif data.type == 3 then
      data.amount = check_amount()
      set_active(data)
      set_redstone(data)
    end
  end
end

local function log()
  local log_pos = 1
  local sum_pos = 5
  term.clear()
  term.setCursorPos(1,1)
  for i, data in ipairs(item_data) do
    if data.type == 1 then
      term.setCursorPos(1,log_pos)
      print(data.name .. ": " .. data.amount .. " / " .. data.target)
      log_pos = log_pos + 1
    elseif data.type == 3 then
      term.setCursorPos(1,sum_pos)
      print("Celkovy pocet: " .. data.amount)
    end
  end
end

local function set_input()
  local log_pos = 2
  
  term.clear()
  term.setCursorPos(1,1)
  print("Zadaj mnozstvo")
  
  for i, data in ipairs(item_data) do
    if data.type == 1 then
      term.setCursorPos(1,log_pos)
      print(data.name .. ": ")
      term.setCursorPos(1,log_pos + 1)
      data.target = tonumber(read())
      log_pos = log_pos + 3
    elseif data.type == 3 then
      term.setCursorPos(1, log_pos)
      print("Celkovy pocet: ")
      term.setCursorPos(1,log_pos + 1)
      data.target = tonumber(read())
      log_pos = log_pos + 3
    end
  end 
end

---loop---
if need_setup == true then
  set_input()
end

while true do
  logic()
  log()

  if check_production() == false then
    break
  end
end

local input = read()
os.reboot()
