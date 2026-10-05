-- receiver [turtleID] [protocol] or receiver fleet [controllerID]
local network = require("network")
local model = require("fleet_model")
local display = require("fleet_display")
local args = { ... }
local fleetMode = args[1] == "fleet"
local filter = not fleetMode and args[1] and tonumber(args[1])
local controller = fleetMode and args[2] and tonumber(args[2])
if (not fleetMode and args[1] and not filter) or (fleetMode and args[2] and not controller) then
    error("Pouzitie: receiver [turtleID] [protocol] alebo receiver fleet [ID_PC]", 0)
end
local protocol = not fleetMode and args[2] or model.telemetryProtocol
protocol = protocol or model.telemetryProtocol
local ok, err = network.open(); if not ok then error("Pripoj modem: " .. tostring(err), 0) end
local screen = peripheral.find("monitor") or term.current()
if screen.setTextScale then screen.setTextScale(0.5) end
local devices, snapshot, selection = {}, { workers = {} }, 0
local hasFleet = false
local lastFleet = 0
local lastDraw = -math.huge
local function valid(p, sender)
    return type(p) == "table" and p.version == 1 and p.id == sender
        and type(p.message) == "string" and #p.message <= 4096
        and (p.position == nil or type(p.position) == "table")
end
local function validFleet(p, sender)
    if type(p) ~= "table" or p.version ~= 1 or p.id ~= sender or p.kind ~= "fleet_snapshot"
        or type(p.workers) ~= "table" or type(p.summary) ~= "table" then return false end
    local count = 0
    for id, w in pairs(p.workers) do
        if type(id) ~= "number" or type(w) ~= "table" or (w.packet ~= nil and type(w.packet) ~= "table") then return false end
        if w.jobNumber~=nil and type(w.jobNumber)~="number" then return false end
        count = count + 1
    end
    if p.jobs~=nil then
        if type(p.jobs)~="table" then return false end
        local jobCount=0
        for _,job in pairs(p.jobs) do
            jobCount=jobCount+1
            if jobCount>33 or type(job)~="table" or type(job.summary)~="table" then return false end
        end
    end
    return count <= 32
end
local function draw()
    lastDraw=os.clock()
    if not hasFleet then
        local summary = { total = 0, completed = 0, remaining = 0, active = 0, failed = 0 }
        snapshot.workers = {}
        for id, entry in pairs(devices) do
            local p = entry.packet
            snapshot.workers[id] = { packet = p, status = p.activity, age = math.floor(os.clock() - entry.received) }
            local progress = type(p.progress) == "table" and p.progress or {}
            if type(progress.total) == "number" and type(progress.completed) == "number" then
                summary.total, summary.completed = summary.total + progress.total, summary.completed + progress.completed
            end
            if p.level == "error" then summary.failed = summary.failed + 1 else summary.active = summary.active + 1 end
        end
        summary.remaining = summary.total - summary.completed
        snapshot.summary = summary
    else
        snapshot.message = "PC #" .. controller .. " (" .. math.floor(os.clock()-lastFleet) .. "s od spravy)"
    end
    local ids = display.ids(snapshot)
    if filter then for i, id in ipairs(ids) do if id == filter then selection = i end end
    elseif not hasFleet and #ids == 1 then selection = 1 end
    selection = display.draw(screen, snapshot, selection, screen.setTextScale ~= nil)
end
local function receive()
    while true do
        local sender, packet, receivedProtocol = rednet.receive(nil, 1)
        if sender and (fleetMode or not filter) and receivedProtocol == model.viewProtocol
            and (not controller or controller == sender) and validFleet(packet, sender) then
            controller, snapshot, hasFleet, lastFleet = sender, packet, true, os.clock()
        elseif sender and not fleetMode and not hasFleet and (not receivedProtocol or receivedProtocol == protocol)
            and (not filter or sender == filter) and valid(packet, sender) then
            if not devices[sender] then
                local count, oldestId, oldestTime = 0, nil, math.huge
                for id, entry in pairs(devices) do
                    count = count + 1
                    if entry.received < oldestTime then oldestId, oldestTime = id, entry.received end
                end
                if count >= 32 then devices[oldestId] = nil end
            end
            devices[sender] = { packet = packet, received = os.clock() }
            snapshot.message = "Posledna sprava od #" .. sender
        end
        if os.clock()-lastDraw>=1 then draw() end
    end
end
local function input()
    while true do
        local event, key = os.pullEvent()
        local count = #display.ids(snapshot)
        if event == "key" then
            if key == keys.right or key == keys.tab then selection = (selection + 1) % (count + 1)
            elseif key == keys.left then selection = (selection - 1) % (count + 1)
            elseif key == keys.zero or key == keys.numPad0 then selection = 0 end
            draw()
        end
    end
end
parallel.waitForAny(receive, input)
