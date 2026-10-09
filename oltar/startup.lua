-- Boot the installed role without requiring network access for an update.
local args = { ... }
local directory = fs.getDir(shell.getRunningProgram())
local rolePath = fs.combine(directory, "oltar-role.txt")
local programs = { main = "main.lua", client = "client.lua", router = "router.lua" }
local role
if args[1] ~= "setup" and fs.exists(rolePath) then
    local f = assert(fs.open(rolePath, "r"))
    role = f.readAll():match("^%s*(%w+)%s*$")
    f.close()
end
if not programs[role] then
    print("Nastavenie automatickeho startu oltara")
    repeat
        write("Uloha PC (main/client/router): ")
        role = read():lower():match("^%s*(%w+)%s*$")
    until programs[role]
    local f = assert(fs.open(rolePath, "w"))
    f.write(role); f.close()
end
local program = fs.combine(directory, programs[role])
if not fs.exists(program) then
    printError("Chyba " .. program .. ". Spusti update " .. role .. ".")
    return
end
print("Oltar: spustam " .. role)
shell.run(program)
