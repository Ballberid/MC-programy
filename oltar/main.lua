-- Hlavny PC: front = povolenie, left = spawner, back = Mekanism teleporter.
local PROTOCOL = "oltar.v1"
local INTERVAL = 2
local states, owners = {}, {}
local frequency
local previousInput, previousOutput, teleportError
local previousTarget = false

local function setSpawner(active)
    redstone.setOutput("left", active)
    if previousOutput ~= active then
        print("Spawner (left): " .. tostring(active))
        previousOutput = active
    end
end

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

local function tryFrequency(name)
    local ok, err = pcall(setFrequency, name)
    if not ok then
        setSpawner(false)
        local message = tostring(err)
        if teleportError ~= message then
            printError("Teleport: " .. message)
            print("Spawner vypnuty. Po oprave teleportera automaticky skusim znova.")
        end
        teleportError = message
        return false
    end
    teleportError = nil
    return true
end

local function update()
    -- Vypnutie vstupu musi zastavit spawner aj pred pripadnou chybou teleportu.
    local enabled = redstone.getInput("front")
    if previousInput ~= enabled then
        print("Vstup (front): " .. tostring(enabled))
        previousInput = enabled
    end
    if not enabled then
        setSpawner(false)
        return
    end
    local target
    for i = 1, 4 do
        local name = "oltar_" .. i
        if states[name] ~= true then target = name; break end
    end
    if previousTarget ~= target then
        print(target and ("Doplnam: " .. target) or "Vsetky 4 oltare maju True: spawner vypnuty.")
        previousTarget = target
    end
    if not target then
        setSpawner(false)
        return
    end
    if tryFrequency(target) then
        -- Nastavovanie periferie moze cakat; znova precitaj vstup pred zapnutim.
        setSpawner(redstone.getInput("front"))
    end
end

local function run()
    setSpawner(redstone.getInput("front"))
    tryFrequency("oltar_1")
    openNetwork()
    print("Hlavny PC ID: " .. os.getComputerID())
    print("Ukoncit: Ctrl+T")
    -- Po restarte nikdy nepouzivame stare obsadenie ulozene na disku.
    rednet.broadcast({ kind = "query" }, PROTOCOL)
    local timer = os.startTimer(INTERVAL)
    local inputTimer = os.startTimer(0.25)
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
        elseif event == "timer" and sender == inputTimer then
            update()
            inputTimer = os.startTimer(0.25)
        elseif event == "peripheral_detach" and sender == "back" then
            frequency = nil
            setSpawner(false)
            printError("Teleporter bol odpojeny. Cakam na opatovne pripojenie.")
        elseif event == "peripheral" and sender == "back" then
            frequency = nil
            update()
        end
    end
end

local ok, err = pcall(run)
redstone.setOutput("left", false)
if not ok then printError(tostring(err)) end
