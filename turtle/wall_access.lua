-- Interior wall access. Corners and the final opening are completed outside.
local nav=require("navigation")
local supplies=require("supplies")
local config=require("config")
local plan=require("wall_plan")
local cuboid=require("cuboid")
local obstacles=require("obstacles")
local position=require("position")
local access={}
function access.new(box)
    local a={}
    local function outside(block)
        local result={}
        if block.x==box.min.x then result[#result+1]={x=block.x-1,y=block.y,z=block.z,direction=1} end
        if block.x==box.max.x then result[#result+1]={x=block.x+1,y=block.y,z=block.z,direction=3} end
        if block.z==box.min.z then result[#result+1]={x=block.x,y=block.y,z=block.z-1,direction=2} end
        if block.z==box.max.z then result[#result+1]={x=block.x,y=block.y,z=block.z+1,direction=0} end
        return result
    end
    local function same(p,q) return p.x==q.x and p.y==q.y and p.z==q.z end
    local function inside(block)
        if same(block,box.opening) or (block.x==box.min.x or block.x==box.max.x)
            and (block.z==box.min.z or block.z==box.max.z) then return nil end
        if block.x==box.min.x then return {x=block.x+1,y=block.y,z=block.z,direction=3} end
        if block.x==box.max.x then return {x=block.x-1,y=block.y,z=block.z,direction=1} end
        if block.z==box.min.z then return {x=block.x,y=block.y,z=block.z+1,direction=0} end
        if block.z==box.max.z then return {x=block.x,y=block.y,z=block.z-1,direction=2} end
    end
    local function interior(p) return cuboid.contains(box,p) and not plan.isWall(box,p) end
    local function gatePoints()
        local outer=outside(box.opening)[1]
        local inner={x=2*box.opening.x-outer.x,y=box.opening.y,z=2*box.opening.z-outer.z,
            direction=(outer.direction+2)%4}
        return outer,inner
    end
    local function move(p)
        local options=assert(supplies.navigationOptions()); options.direction=p.direction
        return nav.moveToCoord(p.x,p.y,p.z,options)
    end
    local function cross(target)
        local current=nav.getPosition()
        if interior(current)==interior(target) then return true end
        local outer,inner=gatePoints()
        local first,second=outer,inner
        if interior(current) then first,second=inner,outer end
        -- Fleet traffic reserves the gate before approaching either endpoint.
        if box.segment then return move(second) end
        local ok,err=move(first); if not ok then return false,err end
        return move(second)
    end
    function a.stand(block) return inside(block) or outside(block)[1] end
    function a.reach(block,preferred,outsideOnly)
        local points=outside(block)
        local inner=not outsideOnly and inside(block)
        if inner then
            if box.includeCorners then table.insert(points,1,inner) else points={inner} end
        end
        local lastError
        for _,p in ipairs(points) do
            local start=nav.getPosition()
            local distance=nav.estimateDistance(p)
            local ready,err=supplies.ensure({moves=distance+12})
            if not ready then return nil,err end
            local crossed,crossErr=cross(p)
            if not crossed then
                if crossErr~="target_unreachable" and crossErr~="no_route" and crossErr~="move_limit"
                    and crossErr~="replan_limit" and crossErr~="search_limit" then return nil,crossErr end
                local back=assert(supplies.navigationOptions()); back.knownOnly,back.direction=true,start.direction
                local returned,returnErr=nav.moveToCoord(start.x,start.y,start.z,back)
                if not returned then return nil,"approach_return_failed:"..tostring(returnErr) end
                lastError=crossErr
            else
                distance=nav.estimateDistance(p)
                local options=assert(supplies.navigationOptions())
                options.direction=p.direction
                options.maxDetour=math.min(2,config.load().navigation.maxDetour)
                options.maxMoves=math.min(config.load().navigation.maxMoves,distance+12)
                local adjacent=nav.distance(nav.getPosition(),p)<=1
                if adjacent then options.maxMoves,options.maxDetour,options.positionVerified=1,0,true end
                local ok,reason=nav.moveToCoord(p.x,p.y,p.z,options)
                if not ok and adjacent and (reason=="target_unreachable" or reason=="no_route") then
                    options.maxMoves=math.min(config.load().navigation.maxMoves,distance+12)
                    options.maxDetour=math.min(2,config.load().navigation.maxDetour)
                    ok,reason=nav.moveToCoord(p.x,p.y,p.z,options)
                end
                if ok then return "front",p end
                lastError=reason
                if reason~="target_unreachable" and reason~="no_route" and reason~="move_limit"
                    and reason~="replan_limit" and reason~="search_limit" then return nil,reason end
                local back=assert(supplies.navigationOptions()); back.knownOnly,back.direction=true,start.direction
                local returned,returnErr=nav.moveToCoord(start.x,start.y,start.z,back)
                if not returned then return nil,"approach_return_failed:"..tostring(returnErr) end
            end
        end
        return nil,"wall_unreachable:"..tostring(lastError)
    end
    function a.clear(block,name,progress,ensureMaterial,force)
        for _=1,16 do
            local synced,err=nav.checkPosition(); if not synced then return false,err end
            local p=nav.getPosition(); local target=position.offset(p,p.direction,"front")
            if not plan.isWall(box,block) or plan.isWall(box,p) or nav.distance(target,block)~=0 then
                return false,"wall_work_position_changed"
            end
            local clear,waitErr,present,existing=obstacles.waitForTurtle("front",nav.checkpoint)
            if not clear then return false,waitErr end
            if not present or not force and existing.name==name then return true end
            if existing.name=="minecraft:water" or existing.name=="minecraft:lava" then return false,"fluid_in_area:"..existing.name end
            if peripheral.hasType("front","inventory") then return false,"inventory_in_area" end
            local supplied,supplyErr=ensureMaterial(); if not supplied then return false,supplyErr end
            local ready,reason=supplies.ensure({moves=1,freeSlots=2,unloadNonfuelSlots=true})
            if not ready then return false,reason end
            synced,err=nav.checkPosition(); if not synced then return false,err end
            p=nav.getPosition(); target=position.offset(p,p.direction,"front")
            if plan.isWall(box,p) or nav.distance(target,block)~=0 then return false,"wall_work_position_changed" end
            clear,waitErr,present,existing=obstacles.waitForTurtle("front",nav.checkpoint)
            if not clear then return false,waitErr end
            if present and (force or existing.name~=name) then
                if existing.name=="minecraft:water" or existing.name=="minecraft:lava" then return false,"fluid_in_area:"..existing.name end
                if peripheral.hasType("front","inventory") then return false,"inventory_in_area" end
                local broken,digErr=turtle.dig()
                if not broken then return false,"dig_failed:"..tostring(digErr) end
                progress.dug=progress.dug+1
            end
        end
        if not turtle.detect() then return true end
        return false,"wall_block_keeps_falling"
    end
    function a.openEntrance(name,progress,ensureMaterial)
        local side,err=a.reach(box.opening,nil,true)
        if not side then return false,err end
        local clear,clearErr=a.clear(box.opening,name,progress,ensureMaterial,true)
        if not clear then return false,clearErr end
        require("pathfinding").mark(box.opening,true)
        return true
    end
    a.inspect=function() return turtle.inspect() end
    a.place=function() return turtle.place() end
    return a
end
return access
