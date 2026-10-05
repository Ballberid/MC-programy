local config = {}
local path = "data/settings.txt"
local cacheDepth,cached=0,nil
-- A running job keeps settings in memory. Saves invalidate the snapshot;
-- outside the job, setup/diagnostics always read the actual file.
function config.withCache(action,...)
    cacheDepth=cacheDepth+1
    local result=table.pack(pcall(action,...))
    cacheDepth=cacheDepth-1
    if cacheDepth==0 then cached=nil end
    if not result[1] then error(result[2],0) end
    return table.unpack(result,2,result.n)
end

function config.defaults()
    return {
        version = 1, stations = {}, protectedItems = {}, fuelSlots = {},
        navigation = {
            reserve = 20, maxDetour = 12, maxNodes = 6000,
            maxMoves = 512, maxReplans = 128, retries = 2,
            gpsEvery = 16, maxProbeHeight = 8,
        },
        telemetry = { enabled = true, protocol = "craftoria.turtle.v1", interval = 2 },
    }
end

function config.isPoint(p)
    if type(p) ~= "table" then return false end
    for _, axis in ipairs({ "x", "y", "z" }) do
        local n = p[axis]
        if type(n) ~= "number" or n ~= n or math.abs(n) == math.huge or n % 1 ~= 0 then return false end
    end
    return true
end

function config.isDirection(d)
    return type(d) == "number" and d % 1 == 0 and d >= 0 and d <= 3
end

function config.validate(c)
    if type(c) ~= "table" or c.version ~= 1 then return false, "invalid_config_version" end
    for _, name in ipairs({ "start", "home" }) do
        if not config.isPoint(c[name]) or not config.isDirection(c[name].direction) then return false, "invalid_" .. name end
    end
    if type(c.stations) ~= "table" then return false, "invalid_stations" end
    for name, station in pairs(c.stations) do
        if not config.isPoint(station) or not config.isDirection(station.direction) then return false, "invalid_station_" .. tostring(name) end
        if station.side ~= "front" and station.side ~= "up" and station.side ~= "down" then return false, "invalid_station_side" end
    end
    if type(c.navigation) ~= "table" or type(c.telemetry) ~= "table" then return false, "invalid_options" end
    for key, default in pairs(config.defaults().navigation) do
        local value = c.navigation[key]
        if value == nil then c.navigation[key] = default
        elseif type(value) ~= "number" or value ~= value or value == math.huge or value < 0 or value % 1 ~= 0 then
            return false, "invalid_navigation_" .. key
        end
    end
    if type(c.telemetry.protocol) ~= "string" or c.telemetry.protocol == "" then return false, "invalid_protocol" end
    if type(c.telemetry.interval) ~= "number" or c.telemetry.interval < 0 or c.telemetry.interval == math.huge or c.telemetry.interval ~= c.telemetry.interval then return false, "invalid_interval" end
    if c.telemetry.receiverId ~= nil and (type(c.telemetry.receiverId) ~= "number" or c.telemetry.receiverId < 0 or c.telemetry.receiverId % 1 ~= 0) then return false, "invalid_receiver_id" end
    if type(c.protectedItems) ~= "table" then return false, "invalid_protected_items" end
    c.fuelSlots = c.fuelSlots or {}
    if type(c.fuelSlots) ~= "table" then return false, "invalid_fuel_slots" end
    for _, slot in ipairs(c.fuelSlots) do
        if type(slot) ~= "number" or slot % 1 ~= 0 or slot < 1 or slot > 16 then return false, "invalid_fuel_slot" end
    end
    return true
end

function config.load()
    if cacheDepth>0 and cached then return cached end
    local f = fs.open(path, "r")
    if not f then return nil, "config_missing" end
    local contents = f.readAll()
    f.close()
    local ok, data = pcall(textutils.unserialize, contents)
    if not ok or type(data) ~= "table" then return nil, "config_corrupt" end
    local valid, err = config.validate(data)
    if not valid then return nil, err end
    if cacheDepth>0 then cached=data end
    return data
end

function config.save(data)
    cached=nil
    local ok, err = config.validate(data)
    if not ok then return false, err end
    local contents = textutils.serialize(require("fleet_store").copy(data))
    fs.makeDir("data")
    local f = fs.open(path .. ".tmp", "w")
    if not f then return false, "config_write_failed" end
    f.write(contents)
    f.close()
    if fs.exists(path .. ".bak") then fs.delete(path .. ".bak") end
    if fs.exists(path) then fs.move(path, path .. ".bak") end
    fs.move(path .. ".tmp", path)
    return true
end

return config
