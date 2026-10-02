-- Small durable records shared by the controller and its workers.
local store = {}
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
    fs.makeDir("data")
    local f = fs.open(path .. ".tmp", "w")
    if not f then error("Zapis zlyhal: " .. path, 0) end
    f.write(textutils.serialize(data)); f.close()
    if fs.exists(path .. ".bak") then fs.delete(path .. ".bak") end
    if fs.exists(path) then fs.move(path, path .. ".bak") end
    fs.move(path .. ".tmp", path)
end
function store.copy(data)
    return textutils.unserialize(textutils.serialize(data))
end
return store
