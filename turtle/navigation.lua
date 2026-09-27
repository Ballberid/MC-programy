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

function nav.direction()
    local cur_x, cur_y, cur_z = location()
    turtle.forward()
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

    if direction == nil then
        print("Direction not found!")
    else
        print("Direction: ", direction)
    end
end

function nav.move(x,y,z)

end

return nav
