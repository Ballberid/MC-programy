-- Start the fleet worker automatically when the turtle boots.
if turtle then
    while true do
        -- Existing pairing takes precedence; #16 remains the default for a new turtle.
        local _,err=pcall(function()
            local state=require("fleet_store").load("data/worker-state.txt",{})
            return shell.run("worker",tostring(state.controller or 16))
        end)
        print("Worker sa ukoncil: "..tostring(err)..". Restart o 10 sekund.")
        sleep(10)
        os.reboot()
    end
end
