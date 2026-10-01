fl = require("fuel")

local nav = {}

-- 0 = North  (-Z)
-- 1 = East   (+X)
-- 2 = South  (+Z)
-- 3 = West   (-X)

local direction = nil
local directionNames = {
    [0] = "-Z (North)",
    [1] = "+X (East)",
    [2] = "+Z (South)",
    [3] = "-X (West)"
}

function nav.setOrigin()
    local x, y, z = gps.locate(5)

    if not x then
        print("GPS pozicia nenajdena")
        return
    end

    fs.makeDir("data")
    local file = fs.open("data/origin.txt", "w")
    file.write(textutils.serialize({
        x = x,
        y = y,
        z = z
    }))

    file.close()
    
    print("Origin ulozeny:")
    print("X:", x, "Y:", y, "Z:", z)
end

function nav.getOrigin()
    local file = fs.open("data/origin.txt", "r")
    local origin = textutils.unserialize(file.readAll())
    file.close()

    return origin.x, origin.y, origin.z
end

local function location()
    local x, y, z = gps.locate()
    return x, y, z
end

function nav.direction()
    local rotCount = 0
    local upCount = 0
    local OK = false

    if turtle.getFuelLevel() < 5 then
        if fl.refuel() < 5 then
            return false
        end
    end
            

    while OK == false do
        if rotCount == 4 then
            rotCount = 0
            if turtle.detectUp() == false then
                turtle.up()
                upCount = upCount + 1
            else
                break
            end
        else
            if turtle.detect() == true then
                turtle.turnLeft()
                rotCount = rotCount + 1
            else
                OK = true
                break
            end
        end
    end

    if OK == true then
        local cur_x, cur_y, cur_z = location()
        turtle.forward()
        local new_x, new_y, new_z = location()
        local dx = new_x - cur_x
        local dz = new_z - cur_z

        if dx < 0 then
            direction = 3
        elseif dx > 0 then
            direction = 1
        end
        if dz < 0 then
            direction = 0
        elseif dz > 0 then
            direction = 2
        end
        
        turtle.back()

        if direction ~= nil and rotCount > 0 then
            direction = (direction + rotCount) % 4
        end
    else
        print("Turtle is blocked!")
    end

    for i = 1, rotCount do
        turtle.turnRight()
    end
    for i = 1, upCount do
        turtle.down()
    end

    if direction ~= nil then
        print("Direction: " .. directionNames[direction])
        return true
    else
        print("Direction not found!")
        return false
    end
end

local function turnToDirection(targetDirection)
    local turn = (targetDirection - direction) % 4

    if turn == 1 then
        turtle.turnRight()
    elseif turn == 2 then
        turtle.turnRight()
        turtle.turnRight()
    elseif turn == 3 then
        turtle.turnLeft()
    end

    direction = targetDirection
end

function nav.move(x,y,z)
    
end

function nav.goHome()
    local cur_x, cur_y, cur_z = location()
    local origin_x, origin_y, origin_z = nav.getOrigin()
    local returnDir_x = nil
    local returnDir_z = nil
    local returnDir = nil
    local dx = origin_x - cur_x
    local dy = origin_y - cur_y
    local dz = origin_z - cur_z

    if nav.direction == false then
        print("Cant go Home")
        return
    end

    if dx > 0 then
        returnDir_x = 1
    elseif dx < 0 then
        returnDir_x = 3
    end
    if dz > 0 then
        returnDir_z = 2
    elseif dz < 0 then
        returnDir_z = 0
    end

    if returnDir_x == (direction + 2) % 4 then
        returnDir = returnDir_x
    elseif returnDir_z == (direction + 2) % 4 then
        returnDir = returnDir_z
    end

    turnToDirection(returnDir)
end

return nav
