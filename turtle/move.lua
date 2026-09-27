local args = {...}

if #args ~= 3 then
    print("Pouzitie:")
    print("move X Y Z")
    return
end

local x = tonumber(args[1])
local y = tonumber(args[2])
local z = tonumber(args[3])

if not x or not y or not z then
    print("Suradnice musia byt cisla")
    return
end

local nav = require("navigation")

nav.move(x, y, z)
