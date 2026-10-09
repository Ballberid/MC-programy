-- Hlavny PC: front = povolenie, left = spawner, back = Mekanism teleporter.
local PROTOCOL = "oltar.v1"
local INTERVAL = 2
local states, owners = {}, {}
local frequency

local function openNetwork()
    local found = false
    for _, side in ipairs(peripheral.getNames()) do
        if peripheral.hasType(side, "modem") then
            rednet.open(side)
            found = true
        end
    end
    assert(found, "Chyba modem. Pripoj modem k PC.")
end

local function setFrequency(name)
    if frequency == name then return end
    local teleporter = peripheral.wrap("back")
    assert(teleporter and type(teleporter.setFrequency) == "function",
        "Na zadnej strane chyba Mekanism teleporter s metodou setFrequency.")
    teleporter.setFrequency(name)
    frequency = name
    print("Teleport -> " .. name)
end

local function update()
    -- Vypnutie vstupu musi zastavit spawner aj pred pripadnou chybou teleportu.
    local enabled = redstone.getInput("front")
    if not enabled then
        redstone.setOutput("left", false)
        return
    end
    local target
    for i = 1, 4 do
        local name = "oltar_" .. i
        if states[name] ~= true then target = name; break end
    end
    if not target then
        redstone.setOutput("left", false)
        return
    end
    setFrequency(target)
    redstone.setOutput("left", true)
end

local function run()
    redstone.setOutput("left", redstone.getInput("front"))
    setFrequency("oltar_1")
    openNetwork()
    print("Hlavny PC ID: " .. os.getComputerID())
    print("Ukoncit: Ctrl+T")
    -- Po restarte nikdy nepouzivame stare obsadenie ulozene na disku.
    rednet.broadcast({ kind = "query" }, PROTOCOL)
    local timer = os.startTimer(INTERVAL)
    update()
    while true do
        local event, sender, message, protocol = os.pullEvent()
        if event == "rednet_message" and protocol == PROTOCOL
            and type(message) == "table" and message.kind == "state"
            and type(message.name) == "string"
            and message.name:match("^oltar_[1-4]$")
            and type(message.active) == "boolean" then
            local name = message.name
            if owners[name] == nil or owners[name] == sender then
                owners[name] = sender
                if states[name] ~= message.active then
                    print(name .. " (PC " .. sender .. "): " .. tostring(message.active))
                end
                states[name] = message.active
                update()
            else
                print("Duplicitny nazov " .. name .. ": ignorujem PC " .. sender)
            end
        elseif event == "redstone" then
            update()
        elseif event == "timer" and sender == timer then
            rednet.broadcast({ kind = "query" }, PROTOCOL)
            update()
            timer = os.startTimer(INTERVAL)
        elseif event == "peripheral_detach" and sender == "back" then
            error("Teleporter bol odpojeny.", 0)
        end
    end
end

local ok, err = pcall(run)
redstone.setOutput("left", false)
if not ok then printError(tostring(err)) end
