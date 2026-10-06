-- worker <controllerID> [known direction 0..3]. Run from each turtle's own dock.
local args = { ... }
local network = require("network")
local config = require("config")
local nav = require("navigation")
local stations = require("stations")
local supplies = require("supplies")
local telemetry = require("telemetry")
local transit = require("transit")
local taskLib = require("fleet_task")
local model = require("fleet_model")
local store = require("fleet_store")
local controller = tonumber(args[1]) or store.load("data/worker-state.txt", {}).controller
if not controller or controller < 0 or controller % 1 ~= 0 then error("Pouzitie: worker ID_hlavneho_PC [smer 0..3]", 0) end
local opened, openErr = network.open(); if not opened then error(openErr, 0) end
local heading = args[2] and tonumber(args[2])
if args[2] and not config.isDirection(heading) then error("Neplatny smer", 0) end
local ready, err = nav.init(heading); if not ready then error(err, 0) end
local dock = nav.getPosition()
local c = config.load()
if not c then
    c = config.defaults(); c.start, c.home = store.copy(dock), store.copy(dock)
    local saved, saveErr = config.save(c); if not saved then error(saveErr, 0) end
end
local client = require("fleet_client").new(controller, dock)
print("Turtle #" .. os.getComputerID() .. " -> riadiaci PC #" .. controller)
print("Stav: " .. client.state.status .. "; cakam na ulohy.")
local function execute()
    while true do
        if client.queued then
            client.queued = false
            local job = client.state.task
            local settings, reason, box = taskLib.settings(job, client.state.dock, client.state.previous)
            local ok, result, progress = false, reason, nil
            if settings then
                local saved, saveErr = config.save(settings)
                if not saved then error(saveErr, 0) end
                assert(transit.configure(job.tunnel, box, job.floor, job.lane))
                telemetry.configure(settings.telemetry, nav.getPosition)
                telemetry.setProgress(client.state.progress)
                telemetry.setContext({ taskId = job.id, jobId = job.jobId })
                local motion=require("fleet_motion").new(client, settings.stations, nav.getPosition, client.state.dock)
                if job.kind=="walls" then motion=require("wall_traffic").new(client,box,motion) end
                nav.setRuntime(motion, client.checkpoint, transit.estimate)
                stations.setRuntime(client.acquire, client.release,true)
                client.state.status = "running"; client.save(); client.status(true)
                local ran, a, b, p = pcall(function()
                    if client.recovery then
                        local prepared, prepareErr = supplies.prepare()
                        if not prepared then return false, prepareErr end
                        local returned, returnErr = nav.goHome(assert(supplies.navigationOptions()))
                        local previous = store.copy(client.state.progress or
                            { completed = 0, total = box.volume, remaining = box.volume, dug = 0 })
                        previous.returnedHome, previous.phase = returned, "failed"
                        return false, returned and "recovered_to_dock" or returnErr, previous
                    end
                    if not client.retry then
                        telemetry.setActivity("waiting_start")
                        local untilTime=os.clock()+(job.startDelay or 0)
                        while os.clock()<untilTime do
                            local allowed,denied=client.checkpoint(); if not allowed then return false,denied end
                            sleep(0.2)
                        end
                    end
                    if nav.distance(nav.getPosition(),client.state.dock)==0 then
                        telemetry.setActivity("leaving_dock")
                        local turned,turnErr=nav.turnToDirection(client.state.dock.direction)
                        if not turned then return false,turnErr end
                        local left,leaveErr=nav.step("front",{anchor=client.state.dock,reserve=settings.navigation.reserve,waitForTurtles=true})
                        if not left then return false,"dock_exit_blocked:"..tostring(leaveErr) end
                    end
                    if job.kind == "floor" then return require("building").run(job.a, job.b, job.block, nil, job.area) end
                    if job.kind == "ceiling" then return require("building").runCeiling(job.a, job.b, job.block, nil, job.area) end
                    if job.kind=="walls" then
                        local options=store.copy(job.wallOptions)
                        options.beforeClose=client.awaitWalls
                        return require("building").runWalls(job.a,job.b,job.block,nil,nil,options)
                    end
                    return require("mining").run(job.a, job.b, nil, client.retry and client.state.progress or nil)
                end)
                ok, result, progress = ran and a == true, ran and b or tostring(a), ran and p or nil
                if (ok or (progress and progress.returnedHome)) and nav.distance(nav.getPosition(), client.state.dock) == 0 then
                    for resource in pairs(client.held) do
                        client.held[resource].depth = 1; client.release(resource)
                    end
                end
                nav.setRuntime(nil, nil, nil); stations.setRuntime(nil, nil)
                if client.state.previous then
                    local restored, restoreErr = config.save(client.state.previous)
                    if not restored then error(restoreErr, 0) end
                end
            end
            if not ok and (not progress or not progress.returnedHome) then
                client.state.status, client.state.error, client.state.progress = "recovery", result, progress or telemetry.getProgress()
                client.paused, client.cancel = false, false
                client.save(); client.status(true)
            else client.finish(ok, result, progress) end
            print(ok and "Uloha hotova. Cakam." or ("Uloha zastavena: " .. tostring(result)))
        end
        sleep(0.2)
    end
end
local function receive()
    while true do
        local sender, packet = rednet.receive(model.protocol, 1)
        if sender then client.handle(sender, packet) end
        client.status()
    end
end
parallel.waitForAny(receive, execute)
