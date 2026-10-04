-- Moving turtles are temporary occupants, never blocks to dig or mark as walls.
local telemetry = require("telemetry")
local obstacles = {}
function obstacles.isTurtle(block)
    return block and type(block.name) == "string" and block.name:match("^computercraft:turtle") ~= nil
end
function obstacles.waitForTurtle(side, checkpoint, timeout)
    local inspect = ({front=turtle.inspect, up=turtle.inspectUp, down=turtle.inspectDown})[side]
    local waiting, started = false, os.clock()
    while true do
        local allowed, reason = checkpoint()
        if not allowed then return false, reason end
        local present, block = inspect()
        if not present or not obstacles.isTurtle(block) then
            if waiting then telemetry.log("Turtle uvolnila cestu, pokracujem.") end
            return true, nil, present, block
        end
        if not waiting then
            telemetry.log("Cakam na inu turtle v ceste."); waiting = true
            telemetry.setActivity("waiting_turtle")
        end
        if timeout and os.clock()-started >= timeout then return false, "turtle_wait_timeout" end
        sleep(0.5)
    end
end
return obstacles
