-- One renderer for the controller monitor and the pocket's paged view.
local display = {}
local frames=setmetatable({}, {__mode="k"})
local names={floor="podlaha",ceiling="strop",walls="steny",quarry="vykop"}
function display.taskType(w)
    if w.status=="idle" then return nil end
    local p=w.packet or {}
    local kind=w.taskType or (type(p.progress)=="table" and p.progress.taskType)
    if names[kind] then return kind end
    local activity=tostring(p.activity or w.status or "")
    if activity=="mining" or activity:match("^quarry") then return "quarry" end
    return activity:match("^building_(%w+)$")
end
function display.ids(snapshot)
    local ids = {}; for id in pairs(snapshot.workers or {}) do ids[#ids+1] = id end
    table.sort(ids); return ids
end
function display.groups(snapshot)
    local groups={{title="STAVANIE",ids={},total=0,completed=0},
        {title="KOPANIE",ids={},total=0,completed=0}, {title="OSTATNE / PRIPRAVENE",ids={},total=0,completed=0}}
    for _,id in ipairs(display.ids(snapshot)) do
        local w=snapshot.workers[id]; local kind=display.taskType(w)
        local g=groups[(kind=="floor" or kind=="ceiling" or kind=="walls") and 1 or (kind=="quarry" and 2 or 3)]
        g.ids[#g.ids+1]=id
        local p=w.packet or {}; local progress=type(p.progress)=="table" and p.progress or {}
        if w.status=="idle" then progress={} end
        local total=tonumber(progress.total) or tonumber(w.taskTotal) or 0
        g.total=g.total+math.max(0,total)
        g.completed=g.completed+math.max(0,math.min(total,tonumber(progress.completed) or 0))
    end
    if type(snapshot.jobs)=="table" then
        for _,g in ipairs(groups) do g.total,g.completed=0,0 end
        for _,job in ipairs(snapshot.jobs) do
            local kind=job.kind
            local g=groups[(kind=="floor" or kind=="ceiling" or kind=="walls") and 1 or (kind=="quarry" and 2 or 3)]
            local s=job.summary or {}
            g.total=g.total+(tonumber(s.total) or 0); g.completed=g.completed+(tonumber(s.completed) or 0)
        end
    end
    local result={}; for _,g in ipairs(groups) do if #g.ids>0 then result[#result+1]=g end end
    return result
end
function display.draw(screen, snapshot, selection, wide)
    local width, height = screen.getSize()
    local row,lines = 1,{}
    local function out(value, wrap)
        local text = tostring(value or "?"):gsub("[%c]", " "):sub(1, 200)
        repeat
            if row > height - 1 then return end
            lines[row]=text:sub(1,width); row = row + 1
            text = text:sub(width+1)
        until wrap == false or #text == 0
    end
    local ids = display.ids(snapshot)
    selection = math.max(0, math.min(selection or 0, #ids))
    local pageLabel=""
    out("Craftoria", false)
    out(snapshot.message or "Cakam na telemetriu...", false)
    if selection == 0 then
        local s = snapshot.summary or {}
        out("Hotove: " .. (s.completed or 0) .. "/" .. (s.total or 0))
        out("Zostava: " .. (s.remaining or 0))
        if s.kind == "floor" or s.kind == "ceiling" or s.kind=="walls" then out("Polozene: " .. (s.placed or 0) .. " Ex.: " .. (s.skipped or 0)) end
        out("Ulohy: " .. (s.active or 0) .. " Problemy: " .. (s.failed or 0))
        out("Turtle: " .. #ids .. "  Servis: " .. (snapshot.serviceOwners and #snapshot.serviceOwners>0 and table.concat(snapshot.serviceOwners,",") or tostring(snapshot.serviceOwner or "volny")))
        out("Tunel: " .. (snapshot.tunnelOwners and #snapshot.tunnelOwners>0 and table.concat(snapshot.tunnelOwners,",") or tostring(snapshot.tunnelOwner or "volny")))
        local detailed=wide and width>=60
        if detailed then out("ID   PRACA/#ULOHA STAV       PALIVO SLOT HOTOVE/CELKOM",false) end
        -- Page whole groups or repeat the heading when a group spans pages.
        local capacity=height-row
        local pages={{}}
        local function append(text) local page=pages[#pages]; page[#page+1]=text end
        for _,g in ipairs(display.groups(snapshot)) do
            local header=g.title.." ("..#g.ids..") "..g.completed.."/"..g.total
            local headingNeeded=true
            for _,id in ipairs(g.ids) do
                if capacity<2 then break end
                if #pages[#pages]+(headingNeeded and 2 or 1)>capacity then
                    pages[#pages+1]={}; headingNeeded=true
                end
                if headingNeeded then append(header); headingNeeded=false end
                local w = snapshot.workers[id]; local p = w.packet or {}
                local progress = type(p.progress) == "table" and p.progress or {}
                local inventory = type(p.inventory) == "table" and p.inventory or {}
                local taskName=(names[display.taskType(w)] or "-")..(w.jobNumber and ("/"..w.jobNumber) or "")
                if detailed then append(string.format("%-4s %-12s %-10s %-6s %-4s %s/%s", tostring(id), taskName,tostring(w.status or p.activity or "?"):sub(1,10),
                    tostring(p.fuel or "?"), tostring(inventory.freeSlots or "?"),
                    tostring(progress.completed or 0), tostring(progress.total or w.taskTotal or 0)))
                else append("#"..id.." "..tostring(w.status or "?").." "..taskName) end
                if w.error and #pages[#pages]<capacity then append("  ! "..w.error) end
            end
        end
        local page=math.floor(os.clock()/5)%#pages+1
        if #pages>1 then pageLabel=" "..page.."/"..#pages end
        for _,line in ipairs(pages[page]) do out(line,false) end
    else
        local id = ids[selection]; local w = snapshot.workers[id]; local p = w.packet or {}
        out("#" .. id .. " " .. tostring(p.label or w.label or "") .. " (" .. tostring(w.age or 0) .. "s)", false)
        if w.jobNumber then out("Uloha #"..w.jobNumber..": "..(names[display.taskType(w)] or "?")) end
        out("Palivo: " .. tostring(p.fuel or "?"))
        local inventory = type(p.inventory) == "table" and p.inventory or {}
        out("Volne sloty: " .. tostring(inventory.freeSlots or "?"))
        local progress = p.progress
        if type(progress) == "table" and type(progress.completed) == "number" and type(progress.total) == "number"
            and type(progress.remaining) == "number" then
            out("Hotove: " .. progress.completed .. "/" .. progress.total)
            out("Zostava: " .. progress.remaining)
            if progress.taskType == "floor" or progress.taskType == "ceiling" or progress.taskType == "walls" then
                out("Polozene: " .. tostring(progress.placed or 0))
                out("Existujuce: " .. tostring(progress.skipped or 0))
            else out("Rozbite bloky: " .. tostring(progress.dug or 0)) end
        end
        out("Stav: " .. tostring(p.activity or w.status or "?") .. " | " .. tostring(p.level or "info"))
        if w.pendingControl then out("Caka povel: " .. w.pendingControl) end
        local pos = p.position
        if type(pos) == "table" then
            out("XYZ: " .. tostring(pos.x) .. "," .. tostring(pos.y) .. "," .. tostring(pos.z) .. " dir=" .. tostring(pos.direction))
        end
        out(w.error or p.message)
    end
    lines[height]=(selection == 0 and ("0 prehlad"..pageLabel.." | sipky detail") or (selection .. "/" .. #ids .. " sipky | 0 prehlad")):sub(1,width)
    local previous=frames[screen]
    if not previous or previous.width~=width or previous.height~=height then
        screen.clear(); previous={}; frames[screen]={width=width,height=height}
    end
    local frame=frames[screen]
    for y=1,height do
        local text=lines[y] or ""
        if previous[y]~=text then
            screen.setCursorPos(1,y); screen.write(text..string.rep(" ",math.max(0,#(previous[y] or "")-#text)))
        end
        frame[y]=text
    end
    return selection
end
return display
