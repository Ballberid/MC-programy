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
local returnDist = {
    x = 0,
    y = 0,
    z = 0,
    distance = 0
}

function nav.setOrigin()
    local x, y, z = gps.locate(5)

    if not x then
        print("GPS pozicia nenajdena")
        return
    end

    if nav.direction() == false then
        return
    end

    fs.makeDir("data")
    local file = fs.open("data/origin.txt", "w")
    file.write(textutils.serialize({
        x = x,
        y = y,
        z = z,
        startDirection = direction
    }))

    file.close()
    
    print("Origin ulozeny:")
    print("X:", x, "Y:", y, "Z:", z)
    print("Start direction: " .. directionNames[direction])
end

function nav.getOrigin()
    local file = fs.open("data/origin.txt", "r")
    local origin = textutils.unserialize(file.readAll())
    file.close()
    
    return origin.x, origin.y, origin.z, origin.startDirection
end

local function location()
    local x, y, z = gps.locate()
    return x, y, z
end

local function returnDistance()
    local cur_x, cur_y, cur_z = location()
    local origin_x, origin_y, origin_z, startDirection = nav.getOrigin()
    
    returnDist.x = origin_x - cur_x
    returnDist.y = origin_y - cur_y
    returnDist.z = origin_z - cur_z

    returnDist.distance = math.abs(returnDist.x) + math.abs(returnDist.y) + math.abs(returnDist.z)
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

local function moveInDirection(dist, dir)
    local distTraveled = 0
    
    turnToDirection(dir)
    for i = 1, dist do
        if turtle.forward() then
            distTraveled = distTraveled + 1
        else

        end
    end
    
    return distTraveled
end

function nav.moveToCoord(x,y,z)
    
end

function nav.goHome()
    local returnDir_x = nil
    local returnDir_z = nil
    local firstDir = nil
    local firstDist = ""
    local secondDir = nil
    local secondDist = ""

    if nav.direction() == false then
        print("Cant go Home")
        return
    end

    returnDistance()

    if returnDist.x > 0 then
        returnDir_x = 1
    else returnDist.x < 0
        returnDir_x = 3
    end
    if returnDist.z > 0 then
        returnDir_z = 2
    else returnDist.z < 0
        returnDir_z = 0
    end

    if returnDir_x == (direction + 2) % 4 then
        firstDir = returnDir_x
        firstDist = "x"
        secondDir = returnDir_z
        secondDist = "z"
    elseif returnDir_z == (direction + 2) % 4 then
        firstDir = returnDir_z
        firstDist = "z"
        secondDir = returnDir_x
        secondDist = "x"
    end

    local first = math.abs(returnDist[firstDist]) - moveInDirection(math.abs(returnDist[firstDist]), firstDir)
    local second = math.abs(returnDist[secondDist]) - moveInDirection(math.abs(returnDist[secondDist]), secondDir)
    if first == 0 and second == 0 then
        local _, _, _, startDirection = nav.getOrigin()
        turnToDirection(startDirection)
        return true
    else
        return false
    end
end

return nav
