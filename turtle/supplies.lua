local config = require("config")
local nav = require("navigation")
local stations = require("stations")
local fuel = require("fuel")
local inv = require("inventory")
local supplies = {}
local jobFuelGoal
-- Scope a job's goal, including cleanup on cancellation/errors and nested jobs.
function supplies.withFuelGoal(goal, action, ...)
    local previous = jobFuelGoal
    jobFuelGoal = goal
    local result = table.pack(pcall(config.withCache,action, ...))
    jobFuelGoal = previous
    if not result[1] then error(result[2], 0) end
    return table.unpack(result, 2, result.n)
end

local function fuelStation()
    return stations.get("fuel")
end

local function validate(request)
    if type(request) ~= "table" then return false, "invalid_request" end
    for _, key in ipairs({ "moves", "freeSlots" }) do
        local value = request[key] or 0
        if type(value) ~= "number" or value ~= value or value == math.huge or value < 0 or value % 1 ~= 0 then return false, "invalid_request:" .. key end
    end
    if (request.freeSlots or 0) > 16 then return false, "invalid_request:freeSlots" end
    if request.materials ~= nil and type(request.materials) ~= "table" then return false, "invalid_materials" end
    for name, amount in pairs(request.materials or {}) do
        if type(name) ~= "string" or type(amount) ~= "number" or amount ~= amount or amount == math.huge or amount < 0 or amount % 1 ~= 0 then return false, "invalid_materials" end
    end
    if request.endpoint and not config.isPoint(request.endpoint) then return false, "invalid_endpoint" end
    if request.unloadFuel ~= nil and type(request.unloadFuel) ~= "boolean" then return false, "invalid_unload_fuel" end
    return true
end

-- Must be called at the start of a job/session. Builds a verified return
-- route to the fuel station; the map is deliberately not trusted on reboot.
function supplies.prepare(heading)
    local c, err = config.load()
    if not c then return false, err end
    nav.configure(c)
    if not nav.getPosition() then
        local ok, reason = nav.init(heading)
        if not ok then return false, reason end
    end
    return stations.verify("fuel")
end

function supplies.check(request)
    request = request or {}
    local valid, invalid = validate(request)
    if not valid then return false, invalid end
    local c, err = config.load()
    if not c then return false, err end
    local station, stationErr = fuelStation()
    if not station then return false, stationErr end
    local returnMoves, routeErr = nav.knownDistance(station)
    if not returnMoves then return false, "fuel_route_unknown:" .. tostring(routeErr) end
    -- The managed shaft route can be longer than a shortcut in the known map.
    returnMoves=math.max(returnMoves,nav.estimateDistance(station))
    local workMoves = request.moves or 0
    -- Without a supplied endpoint, worst-case each work move also lengthens
    -- the known return route by one block.
    local afterReturn = returnMoves + workMoves
    if request.endpoint then
        if not config.isPoint(request.endpoint) then return false, "invalid_endpoint" end
        local knownDistance = nav.knownDistance(station, request.endpoint)
        if knownDistance then afterReturn = math.max(knownDistance,nav.estimateDistance(station,request.endpoint)) end
    end
    local required = fuel.required(workMoves, afterReturn, c.navigation.reserve)
    if not fuel.has(required) then return false, "fuel", { requiredFuel = required } end
    if not inv.hasFreeSlots(request.freeSlots or 0) then return false, "space", { requiredFuel = required } end
    local enough, missing = inv.hasMaterials(request.materials)
    if not enough then return false, "materials", { missing = missing, requiredFuel = required } end
    return true, nil, { requiredFuel = required }
end

function supplies.ensure(request)
    request = request or {}
    local valid, invalid = validate(request)
    if not valid then return false, invalid end
    local station, err = fuelStation()
    if not station then return false, err end
    if not nav.knownDistance(station) then
        local ok, reason = supplies.prepare()
        if not ok then return false, reason end
    end
    local c = config.load()
    local options = { anchor = station, reserve = c.navigation.reserve, keepFuel = request.unloadFuel ~= true,
        unloadNonfuelSlots=request.unloadNonfuelSlots==true }
    local function refuel(minimum)
        local target = minimum
        if jobFuelGoal then
            local goal = jobFuelGoal()
            if type(goal) ~= "number" or goal ~= goal or goal == math.huge or goal < 0 then return false, "invalid_job_fuel_goal" end
            target = math.max(minimum, math.ceil(goal))
        end
        local o = {}
        for key, value in pairs(options) do o[key] = value end
        -- Cap at the station after the actual return distance is known.
        o.capToLimit, o.allowPartial = true, jobFuelGoal ~= nil
        if jobFuelGoal then o.minimumFuel=minimum+32 end
        local limit = turtle.getFuelLimit()
        local distance = nav.knownDistance(station) or 0
        require("telemetry").log("Tankovanie: ciel po navrate " .. math.min(target, math.max(0, limit - distance))
            .. "; odhad zostavajucej prace " .. target .. "; limit " .. limit)
        return stations.refuel(target, o)
    end
    -- Bounded service passes. Each individual visit returns to the work point.
    local toppedUp=false
    for _ = 1, 4 do
        local ok, need, info = supplies.check(request)
        -- Leave for fuel before consuming the last return budget. Evaluate the
        -- full job estimate only near this threshold, never on every step.
        if ok and not toppedUp and jobFuelGoal and not fuel.has(2*info.requiredFuel) then
            local goal=jobFuelGoal()
            if type(goal)~="number" or goal~=goal or goal==math.huge or goal<0 then return false,"invalid_job_fuel_goal" end
            if not fuel.has(goal) then ok,need=false,"fuel" end
        end
        if ok then
            info.navigationOptions={anchor=station,reserve=c.navigation.reserve}
            return true,nil,info
        end
        local serviced, reason
        if need == "fuel" then
            serviced, reason = refuel(info.requiredFuel)
            if serviced then
                toppedUp=true
                local ready, stillNeeded = supplies.check(request)
                if not ready and stillNeeded == "fuel" then return false, "insufficient_fuel" end
            end
        elseif need == "space" or need == "materials" then
            local service = c.stations[need == "space" and "output" or "materials"]
            if not service then return false, "station_missing:" .. need end
            local distance = math.max(nav.knownDistance(service) or 0,nav.estimateDistance(service)) + 6*c.navigation.maxDetour
            -- Include the trip to the service station, not just future work.
            local target = info.requiredFuel + 2 * distance
            if fuel.level() ~= "unlimited" then target = math.min(target, turtle.getFuelLimit()) end
            if not fuel.has(target) then
                serviced, reason = refuel(target)
                if not serviced then return false, reason end
            end
            if need == "space" then
                serviced, reason = stations.unload(request.materials, options)
            else
                if inv.freeSlots() == 0 then
                    serviced, reason = stations.unload(request.materials, options)
                    if not serviced then return false, reason end
                end
                serviced, reason = stations.takeMaterials(request.materials, options)
            end
        else return false, need end
        if not serviced then return false, reason end
    end
    return supplies.check(request)
end

-- Future work programs should use these options for EVERY movement, including
-- building/mining steps, to keep the fuel-station route in their reserve.
function supplies.navigationOptions()
    local station, err = fuelStation()
    if not station then return nil, err end
    if not nav.knownDistance(station) then return nil, "fuel_route_unknown" end
    local c = config.load()
    return { anchor = station, reserve = c.navigation.reserve }
end

return supplies
