-- Start the fleet worker automatically when the turtle boots.
if turtle then
    -- Existing pairing takes precedence; #16 remains the default for a new turtle.
    local state=require("fleet_store").load("data/worker-state.txt",{})
    shell.run("worker",tostring(state.controller or 16))
end
