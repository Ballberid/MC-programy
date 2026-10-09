-- Volitelny samostatny PC s modemom na predlzenie dosahu Rednetu.
local found = false
for _, side in ipairs(peripheral.getNames()) do
    if peripheral.hasType(side, "modem") then
        rednet.open(side)
        found = true
    end
end
assert(found, "Chyba modem. Pripoj modem k routeru.")
print("Oltar router bezi. Ukoncit: Ctrl+T")
shell.run("repeat")
