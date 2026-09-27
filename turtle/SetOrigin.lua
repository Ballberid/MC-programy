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
print("X:", x)
print("Y:", y)
print("Z:", z)
