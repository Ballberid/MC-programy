local nav = {}

-- 0 = North  (-Z)
-- 1 = East   (+X)
-- 2 = South  (+Z)
-- 3 = West   (-X)

local direction = nil

local function getPosition()
    local x, y, z = gps.locate(5)

    if not x then
        error("GPS pozicia nenajdena")
    end

    return x, y, z
end


local function detectDirection()
    local x1, y1, z1 = getPosition()

    -- Musi byt mozne pohnut sa o 1 blok dopredu
    if not turtle.forward() then
        error("Nemozem zistit smer - pred turtle je prekazka")
    end

    local x2, y2, z2 = getPosition()

    turtle.back()

    if x2 > x1 then
        direction = 1 -- East
    elseif x2 < x1 then
        direction = 3 -- West
    elseif z2 > z1 then
        direction = 2 -- South
    elseif z2 < z1 then
        direction = 0 -- North
    else
        error("Nepodarilo sa zistit smer")
    end
end


local function turnRight()
    turtle.turnRight()
    direction = (direction + 1) % 4
end


local function turnLeft()
    turtle.turnLeft()
    direction = (direction + 3) % 4
end


local function face(targetDirection)
    while direction ~= targetDirection do
        local diff = (targetDirection - direction) % 4

        if diff == 1 then
            turnRight()

        elseif diff == 3 then
            turnLeft()

        else
            turnRight()
            turnRight()
        end
    end
end


local function forward()
    if not turtle.forward() then
        return false
    end

    return true
end


function nav.move(targetX, targetY, targetZ)

    if direction == nil then
        detectDirection()
    end

    local x, y, z = getPosition()

    -- Najprv Y
    while y < targetY do
        if not turtle.up() then
            error("Nemozem ist hore")
        end
        y = y + 1
    end

    while y > targetY do
        if not turtle.down() then
            error("Nemozem ist dole")
        end
        y = y - 1
    end


    -- Potom X
    while x < targetX do
        face(1) -- East +X

        if not forward() then
            error("Prekazka pri pohybe +X")
        end

        x = x + 1
    end

    while x > targetX do
        face(3) -- West -X

        if not forward() then
            error("Prekazka pri pohybe -X")
        end

        x = x - 1
    end


    -- Potom Z
    while z < targetZ do
        face(2) -- South +Z

        if not forward() then
            error("Prekazka pri pohybe +Z")
        end

        z = z + 1
    end

    while z > targetZ do
        face(0) -- North -Z

        if not forward() then
            error("Prekazka pri pohybe -Z")
        end

        z = z - 1
    end

    return true
end


function nav.getOrigin()

    if not fs.exists("data/origin.txt") then
        error("Origin nie je nastaveny")
    end

    local file = fs.open("data/origin.txt", "r")
    local origin = textutils.unserialize(file.readAll())
    file.close()

    return origin
end


function nav.moveLocal(x, y, z)

    local origin = nav.getOrigin()

    local worldX = origin.x + x
    local worldY = origin.y + y
    local worldZ = origin.z + z

    return nav.move(worldX, worldY, worldZ)
end


return nav
