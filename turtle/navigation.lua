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

local function location()
    local x, y, z = gps.locate()
    return x, y, z
end

function nav.direction()
    local rotCount = 0
    local upCount = 0
    local OK = false

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
        else
            print("Unknown direction")
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
    else
        print("Direction not found!")
    end
end

function nav.move(x,y,z)

end

return nav
