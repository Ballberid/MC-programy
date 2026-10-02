local config = require("config")
local position = require("position")
local paths = require("pathfinding")
local fuel = require("fuel")
local telemetry = require("telemetry")
local nav = {}
local settings = config.defaults()
local movesSinceGPS = 0
local journey, checkpoint, estimator

function nav.setRuntime(moveHandler, checkHandler, estimateHandler)
    journey, checkpoint, estimator = moveHandler, checkHandler, estimateHandler
end
function nav.checkpoint()
    if checkpoint then return checkpoint() end
    return true
end
function nav.estimateDistance(target, from)
    from = from or position.get()
    if estimator then return estimator(from, target) end
    return paths.distance(from, target)
end

function nav.configure(c)
    settings = c or settings
    telemetry.configure(settings.telemetry, position.get)
end

function nav.init(heading)
    local c = config.load()
    if c then nav.configure(c) end
    paths.clear()
    movesSinceGPS = 0
    local ok, err = position.init(heading, settings.navigation, fuel.slots(settings))
    if ok then paths.mark(position.get(), true) end
    return ok, err
end

function nav.getPosition()
    return position.get()
end

function nav.direction()
    if not position.get() then return nav.init() end
    return position.sync()
end

function nav.turnToDirection(target)
    return position.turnTo(target)
end

function nav.distance(a, b)
    return paths.distance(a, b)
end

function nav.knownDistance(target, from)
    from = from or position.get()
    if not from then return nil, "position_uninitialized" end
    local route, err = paths.find(from, target, { knownOnly = true, maxNodes = settings.navigation.maxNodes })
    if not route then return nil, err end
    return #route
end

function nav.sync()
    local ok, err = position.sync()
    if not ok and err == "position_mismatch" then paths.clear() end
    if ok then movesSinceGPS = 0 end
    return ok, err
end

local function stop(reason, goal, moved)
    telemetry.emit("error", reason, { target = goal, moved = moved }, true)
    return false, reason, { position = position.get(), moved = moved }
end

local function stepToward(nextPoint)
    local p = position.get()
    if nextPoint.y > p.y then return "up" end
    if nextPoint.y < p.y then return "down" end
    local d
    if nextPoint.x > p.x then d = 1
    elseif nextPoint.x < p.x then d = 3
    elseif nextPoint.z > p.z then d = 2
    else d = 0 end
    local ok, err = position.turnTo(d)
    if not ok then return nil, err end
    return "front"
end

local function detect(side)
    return ({ front = turtle.detect, up = turtle.detectUp, down = turtle.detectDown })[side]()
end

local function rawMove(x, y, z, options)
    local goal = { x = x, y = y, z = z }
    options = options or {}
    if not config.isPoint(goal) then return false, "invalid_target" end
    local permitted, denied = nav.checkpoint()
    if not permitted then return false, denied end
    if options.direction ~= nil and not config.isDirection(options.direction) then return false, "invalid_direction" end
    for _, name in ipairs({ "reserve", "maxMoves", "maxDetour", "maxReplans" }) do
        local value = options[name]
        if value ~= nil and (type(value) ~= "number" or value ~= value or value == math.huge or value < 0 or value % 1 ~= 0) then
            return false, "invalid_option:" .. name
        end
    end
    if not position.get() then
        local ok, err = nav.init()
        if not ok then return false, err end
    end
    local synced, syncErr = nav.sync()
    if not synced then return false, syncErr end
    local start = position.get()
    local anchor = options.anchor or settings.stations.fuel or start
    if not config.isPoint(anchor) then return false, "invalid_anchor" end
    local reserve = options.reserve or settings.navigation.reserve
    local maxMoves = options.maxMoves or settings.navigation.maxMoves
    local bounds = paths.bounds(start, goal, options.maxDetour or settings.navigation.maxDetour)
    local known = options.knownOnly == true
    if not known then paths.forgetBlocked() end
    local homeCost, homeErr = nav.knownDistance(anchor)
    if not homeCost then return false, "return_route_unknown:" .. tostring(homeErr) end
    local moved, replans = 0, 0
    telemetry.setActivity("moving")
    while paths.distance(position.get(), goal) > 0 do
        if moved >= maxMoves then return stop("move_limit", goal, moved) end
        local route, routeErr = paths.find(position.get(), goal, {
            bounds = bounds, knownOnly = known, maxNodes = settings.navigation.maxNodes,
        })
        if not route then return stop(routeErr, goal, moved) end
        local obstructed = false
        for _, nextPoint in ipairs(route) do
            local permitted, denied = nav.checkpoint()
            if not permitted then return stop(denied, goal, moved) end
            if moved >= maxMoves then return stop("move_limit", goal, moved) end
            local returnCost = nav.knownDistance(anchor)
            if not returnCost then return stop("return_route_lost", goal, moved) end
            -- Worst case: next step needs to be undone before returning.
            -- Prefer an already known shorter return route when available.
            local nextReturn = nav.knownDistance(anchor, nextPoint)
            nextReturn = nextReturn or (returnCost + 1)
            local enough = fuel.ensure(1 + nextReturn + reserve, fuel.slots(settings))
            if not enough then return stop("fuel_reserve", goal, moved) end
            local side, sideErr = stepToward(nextPoint)
            if not side then return stop(sideErr, goal, moved) end
            local success = false
            for attempt = 0, settings.navigation.retries do
                if detect(side) then break end
                if position.move(side) then success = true; break end
                if attempt < settings.navigation.retries then sleep(0.3) end
            end
            if not success then
                paths.mark(nextPoint, false)
                replans = replans + 1
                if replans > (options.maxReplans or settings.navigation.maxReplans) then return stop("replan_limit", goal, moved) end
                obstructed = true
                telemetry.emit("warning", "obstacle", nextPoint, true)
                break
            end
            paths.mark(nextPoint, true)
            moved = moved + 1
            movesSinceGPS = movesSinceGPS + 1
            telemetry.emit("info", "step", { target = goal })
            if movesSinceGPS >= settings.navigation.gpsEvery then
                local ok, err = nav.sync()
                if not ok then return stop(err, goal, moved) end
            end
        end
        if not obstructed then break end
    end
    local ok, err = nav.sync()
    if not ok then return stop(err, goal, moved) end
    if options.direction ~= nil then
        ok, err = position.turnTo(options.direction)
        if not ok then return stop(err, goal, moved) end
    end
    telemetry.setActivity("arrived")
    return true, nil, { position = position.get(), moved = moved }
end

function nav.moveToCoord(x, y, z, options)
    if journey and position.get() then return journey({ x = x, y = y, z = z }, options or {}, rawMove) end
    return rawMove(x, y, z, options)
end

-- Single steps also obey coordinate tracking and reserve checks.
function nav.step(side, options)
    local p = position.get()
    if not p then return false, "position_uninitialized" end
    if side ~= "front" and side ~= "back" and side ~= "up" and side ~= "down" then return false, "invalid_move" end
    local d = side == "back" and (p.direction + 2) % 4 or p.direction
    local target = position.offset(p, d, side)
    local o = {}
    for key, value in pairs(options or {}) do o[key] = value end
    o.maxMoves, o.maxDetour, o.direction = 1, 0, p.direction
    return nav.moveToCoord(target.x, target.y, target.z, o)
end

function nav.setOrigin()
    local ok, err = nav.direction()
    if not ok then return false, err end
    local p = position.get()
    settings.start, settings.home = p, position.get()
    local saved, saveErr = config.save(settings)
    if not saved then return false, saveErr end
    fs.makeDir("data")
    local f = fs.open("data/origin.txt", "w")
    if not f then return false, "origin_write_failed" end
    f.write(textutils.serialize({ x = p.x, y = p.y, z = p.z, startDirection = p.direction }))
    f.close()
    return true
end

function nav.getOrigin()
    local c = config.load()
    if c then return c.home.x, c.home.y, c.home.z, c.home.direction end
    -- Compatibility with existing origin files.
    local f = fs.open("data/origin.txt", "r")
    if not f then return nil, "origin_missing" end
    local text = f.readAll(); f.close()
    local ok, p = pcall(textutils.unserialize, text)
    if not ok or not config.isPoint(p) or not config.isDirection(p.startDirection) then return nil, "origin_corrupt" end
    return p.x, p.y, p.z, p.startDirection
end

function nav.goHome(options)
    local x, y, z, d = nav.getOrigin()
    if not x then return false, y end
    local o = {}
    for key, value in pairs(options or {}) do o[key] = value end
    o.direction = d
    return nav.moveToCoord(x, y, z, o)
end

return nav
