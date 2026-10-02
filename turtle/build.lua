-- One entry point for standalone building programs.
if not turtle then error("Program build spusti na turtle.", 0) end
local dialog = require("fleet_dialog")
local programs = require("build_programs")
while true do
    print("STAVANIE")
    for index, program in ipairs(programs) do
        print(index .. " - " .. program.name)
        print("  " .. program.description)
    end
    print("0 - Koniec")
    local choice = dialog.number("Vyber program", 0, 0, #programs)
    if choice == 0 then return end
    if not shell.run(programs[choice].command) then
        print("Program skoncil s chybou. Skontroluj vypis vyssie.")
    end
end
