local nav = {}

-- 0 = North  (-Z)
-- 1 = East   (+X)
-- 2 = South  (+Z)
-- 3 = West   (-X)

local direction = nil

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

local function location()
    local x, y, z = gps.locate()
    return x, y, z
end

local function canMove(r, z)
    local frontBlock, frontData = turtle.inspect()
    local rotCount = r or 0
    local upCount = z or 0

    if rotCount == 4 then
        rotCount = 0
        local upBlock, upData = turtle.inspectUp()
        if upBlock == false then
            turtle.up()
            upCount = upCount + 1
            return canMove(rotCount, upCount)
        else
            return false, rotCount, upCount
        end
    end
    
    if frontBlock == false then
        return true, rotCount, upCount
    else
        turtle.turnLeft()
        rotCount = rotCount + 1
        return canMove(rotCount, upCount)
    end
end

function nav.direction()
    local cur_x, cur_y, cur_z = location()
    local canMove, rotCount, upCount = canMove()

    if canMove == true then
        turtle.forward()
    else
        print("Turtle is blocked!")
    end
    
    local new_x, new_y, new_z = location()

    if (new_x - cur_x) <= -1 then
        direction = 3
    elseif (new_x - cur_x) >= 1 then
        direction = 1
    end
    if (new_z - cur_z) <= -1 then
        direction = 0
    elseif (new_z - cur_z) >= 1 then
        direction = 2
    end

    turtle.back()

    for i = 1, rotCount do
        turtle.turnRight()
    end
    for i = 1, upCount do
        turtle.down()
    end

    if direction ~= nil and rotCount > 0 then
        direction = (direction + rotCount) % 4
    end

    if direction == nil then
        print("Direction not found!")
    elseif direction == 0 then
        print("Direction: -Z (North)")
    elseif direction == 1 then
        print("Direction: +X (East)")
    elseif direction == 2 then
        print("Direction: +Z (South)")
    elseif direction == 3 then
        print("Direction: -X (West)")
    else
        print("Unknown direction")
    end
end

function nav.move(x,y,z)

end

return nav
