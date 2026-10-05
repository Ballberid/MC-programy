-- Memoise certified return lengths, not optimistic routes through unknown cells.
-- New free cells extend the cache. Any lost free cell invalidates every field.
local routes={}
local directions={{1,0,0},{-1,0,0},{0,1,0},{0,-1,0},{0,0,1},{0,0,-1}}
local function key(p) return p.x..","..p.y..","..p.z end
local function neighbour(p,d) return {x=p.x+d[1],y=p.y+d[2],z=p.z+d[3]} end
function routes.new(isFree)
    local fields,order={},{}
    local self={}
    function self.clear() fields,order={},{} end
    local function improve(f,p,distance)
        local k=key(p)
        if isFree(p) and (not f.distance[k] or distance<f.distance[k]) then
            f.distance[k]=distance; f.queue[#f.queue+1]=p
        end
    end
    local function adjacent(f,p)
        local best
        for _,d in ipairs(directions) do
            local q=neighbour(p,d)
            local n=isFree(q) and f.distance[key(q)]
            if n and (not best or n+1<best) then best=n+1 end
        end
        return best
    end
    local function relax(f)
        -- Bound background work; every intermediate value is still a real
        -- route length. A later shortcut can only lower the fuel reserve.
        for _=1,32 do
            local p=f.queue[f.head]; if not p then break end
            f.head=f.head+1
            local cost=f.distance[key(p)]
            for _,d in ipairs(directions) do improve(f,neighbour(p,d),cost+1) end
        end
        if f.head>#f.queue then f.queue,f.head={},1 end
    end
    function self.add(p)
        for _,f in pairs(fields) do
            local best=adjacent(f,p)
            if best then improve(f,p,best) end
        end
    end
    function self.distance(start,goal,find)
        if not isFree(goal) then return nil,"target_unreachable" end
        local k=key(goal); local f=fields[k]
        if not f then
            if #order>=8 then fields[table.remove(order,1)]=nil end
            f={distance={},queue={},head=1}; fields[k]=f; order[#order+1]=k
            improve(f,goal,0)
        end
        relax(f)
        local cached=f.distance[key(start)]
        if cached then return cached end
        -- A hypothetical next step is allowed to leave an unknown cell into
        -- the certified map, but must not register that cell as traversable.
        if not isFree(start) then
            local best=adjacent(f,start); if best then return best end
        end
        local path,err=find(start,goal)
        if not path then return nil,err end
        improve(f,start,#path)
        for i,p in ipairs(path) do improve(f,p,#path-i) end
        return #path
    end
    return self
end
return routes
