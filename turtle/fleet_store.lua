-- Small durable records shared by the controller and its workers.
local store = {}
-- CC serialization rejects repeated table references. Persist a value tree:
-- shared sub-tables get independent copies, genuine cycles remain an error.
local function copy(value, parents)
    if type(value) ~= "table" then return value end
    if parents[value] then error("Cannot copy a cyclic table", 0) end
    parents[value] = true
    local result = {}
    for key, item in pairs(value) do result[copy(key, parents)] = copy(item, parents) end
    parents[value] = nil
    return result
end
function store.copy(data)
    return copy(data, {})
end
function store.load(path, default)
    local found = false
    for _, candidate in ipairs({ path, path .. ".tmp", path .. ".bak" }) do
        local f = fs.open(candidate, "r")
        if f then
            found = true
            local text = f.readAll(); f.close()
            local ok, data = pcall(textutils.unserialize, text)
            if ok and type(data) == "table" then return data end
            if candidate == path then error("Poskodeny subor: " .. path, 0) end
        end
    end
    if found then error("Poskodene zalohy: " .. path, 0) end
    return default
end
function store.save(path, data)
    local contents = textutils.serialize(store.copy(data))
    fs.makeDir("data")
    local f = fs.open(path .. ".tmp", "w")
    if not f then error("Zapis zlyhal: " .. path, 0) end
    f.write(contents); f.close()
    if fs.exists(path .. ".bak") then fs.delete(path .. ".bak") end
    if fs.exists(path) then fs.move(path, path .. ".bak") end
    fs.move(path .. ".tmp", path)
end
return store
