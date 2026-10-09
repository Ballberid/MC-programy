-- Pomocny PC: back = senzor, right = signal >= 1 (sila 15), bottom = mobovia pritomni.
local PROTOCOL = "oltar.v2"
local INTERVAL = 2
local args = { ... }
local configPath = fs.combine(fs.getDir(shell.getRunningProgram()), "client-config.txt")

local function valid(config)
    return type(config) == "table" and type(config.name) == "string"
        and config.name:match("^oltar_[1-4]$") ~= nil
        and type(config.mainId) == "number" and config.mainId >= 0
        and config.mainId == math.floor(config.mainId)
        and config.mainId ~= os.getComputerID()
end

local function configure()
    local config
    if args[1] ~= "setup" and fs.exists(configPath) then
        local file = assert(fs.open(configPath, "r"))
        config = textutils.unserialize(file.readAll())
        file.close()
    end
    if not valid(config) then
        repeat
            write("Cislo oltara (1-4): ")
            local number = read()
            write("ID hlavneho PC: ")
            config = { name = "oltar_" .. number, mainId = tonumber(read()) }
            if not valid(config) then print("Neplatne cislo alebo ID. Skus znova.") end
        until valid(config)
    end
    -- Migracia povodneho nastavenia zachova cislo oltara aj ID hlavneho PC.
    if args[1] == "setup" then
        repeat
            write("Sila signalu pri 0 moboch (Enter = 0): ")
            local value = read()
            config.emptySignal = value == "" and 0 or tonumber(value)
        until type(config.emptySignal) == "number" and config.emptySignal >= 0
            and config.emptySignal <= 14 and config.emptySignal == math.floor(config.emptySignal)
    end
    if type(config.emptySignal) ~= "number" or config.emptySignal < 0
        or config.emptySignal > 14 or config.emptySignal ~= math.floor(config.emptySignal) then
        config.emptySignal = 0
    end
    local file = assert(fs.open(configPath, "w"))
    file.write(textutils.serialize(config)); file.close()
    return config
end

local function run()
    redstone.setAnalogOutput("right", 0)
    redstone.setOutput("bottom", false)
    local config = configure()
    local found = false
    for _, side in ipairs(peripheral.getNames()) do
        if peripheral.hasType(side, "modem") then
            rednet.open(side)
            found = true
        end
    end
    assert(found, "Chyba modem. Pripoj modem k PC.")
    print(config.name .. " -> hlavny PC " .. config.mainId)
    print("Pocet mobov = signal - " .. config.emptySignal)
    print("Ukoncit: Ctrl+T; zmena nastavenia: client.lua setup")
    local previous
    local function report()
        local signal = redstone.getAnalogInput("back")
        redstone.setAnalogOutput("right", signal >= 1 and 15 or 0)
        local count = math.max(0, signal - config.emptySignal)
        local active = count > 0
        if not active then redstone.setOutput("bottom", false) end
        rednet.send(config.mainId, {
            kind = "state", name = config.name, count = count,
            signal = signal, capacity = 15 - config.emptySignal,
        }, PROTOCOL)
        -- Pri True najprv odosleme stav, az potom zapneme spodny vystup.
        redstone.setOutput("bottom", active)
        if previous ~= signal then print("Signal: " .. signal .. " / mobovia: " .. count) end
        previous = signal
    end
    report()
    local timer = os.startTimer(INTERVAL)
    local inputTimer = os.startTimer(0.25)
    while true do
        local event, sender, message, protocol = os.pullEvent()
        if event == "redstone" then
            if previous ~= redstone.getAnalogInput("back") then report() end
        elseif event == "timer" and sender == timer then
            report()
            timer = os.startTimer(INTERVAL)
        elseif event == "timer" and sender == inputTimer then
            if previous ~= redstone.getAnalogInput("back") then report() end
            inputTimer = os.startTimer(0.25)
        elseif event == "rednet_message" and sender == config.mainId
            and protocol == PROTOCOL and type(message) == "table"
            and message.kind == "query" then
            report()
        end
    end
end

local ok, err = pcall(run)
redstone.setAnalogOutput("right", 0)
redstone.setOutput("bottom", false)
if not ok then printError(tostring(err)) end
