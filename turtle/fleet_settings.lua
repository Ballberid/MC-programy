local store = require("fleet_store")
local config = require("config")
local transit = require("transit")
local settings = {}
local path = "data/fleet-settings.txt"
function settings.defaults() return { version = 1, stations = {}, defaults = {}, tunnel = nil } end
function settings.validate(c)
    if type(c) ~= "table" or c.version ~= 1 or type(c.stations) ~= "table" or type(c.defaults) ~= "table" then return false, "invalid_fleet_settings" end
    for name, s in pairs(c.stations) do
        if type(name) ~= "string" or name == "" or not config.isPoint(s) or not config.isDirection(s.direction)
            or (s.side ~= "front" and s.side ~= "up" and s.side ~= "down") then return false, "invalid_station" end
    end
    for _, role in ipairs({ "fuel", "output", "materials" }) do
        if c.defaults[role] and not c.stations[c.defaults[role]] then return false, "unknown_default_station" end
    end
    return transit.validate(c.tunnel)
end
function settings.load()
    local c = store.load(path, settings.defaults())
    local ok, err = settings.validate(c)
    if not ok then error(err, 0) end
    return c
end
function settings.save(c)
    local ok, err = settings.validate(c)
    if not ok then return false, err end
    store.save(path, c); return true
end
return settings
