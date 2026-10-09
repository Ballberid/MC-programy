-- Pomocny PC: back = doska/senzor, bottom = vystup.
local PROTOCOL = "oltar.v1"
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
        local file = assert(fs.open(configPath, "w"))
        file.write(textutils.serialize(config))
        file.close()
    end
    return config
end

local function run()
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
    print("Ukoncit: Ctrl+T; zmena nastavenia: client.lua setup")
    local previous
    local function report()
        local active = redstone.getInput("back")
        if not active then redstone.setOutput("bottom", false) end
        rednet.send(config.mainId, {
            kind = "state", name = config.name, active = active,
        }, PROTOCOL)
        -- Pri True najprv odosleme stav, az potom zapneme spodny vystup.
        redstone.setOutput("bottom", active)
        if previous ~= active then print("Signal: " .. tostring(active)) end
        previous = active
    end
    report()
    local timer = os.startTimer(INTERVAL)
    while true do
        local event, sender, message, protocol = os.pullEvent()
        if event == "redstone" then
            if previous ~= redstone.getInput("back") then report() end
        elseif event == "timer" and sender == timer then
            report()
            timer = os.startTimer(INTERVAL)
        elseif event == "rednet_message" and sender == config.mainId
            and protocol == PROTOCOL and type(message) == "table"
            and message.kind == "query" then
            report()
        end
    end
end

local ok, err = pcall(run)
redstone.setOutput("bottom", false)
if not ok then printError(tostring(err)) end
