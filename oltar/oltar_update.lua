-- Run update [main|client|router]. Resolve one commit for all installed files.
local args = { ... }
local role
local rolePath = "oltar-role.txt"
local repo = "Ballberid/MC-programy"
local stage, backup, journal = "data/oltar-update-stage", "data/oltar-update-backup", "data/oltar-update-journal.txt"

local function download(url)
    local response, reason = http.get(url, { ["User-Agent"] = "Oltar-Updater" })
    if not response then error("Stahovanie zlyhalo: " .. tostring(reason) .. " / " .. url, 0) end
    local contents = response.readAll()
    response.close()
    return contents
end

local function readJournal()
    local f = fs.open(journal, "r")
    if not f then return nil end
    local contents = f.readAll(); f.close()
    local data = textutils.unserialize(contents)
    if type(data) ~= "table" then error("Poskodeny update journal. Zachovavam zalohu.", 0) end
    return data
end

local function validName(name)
    return type(name) == "string" and name:match("^[%w_%-]+%.lua$") ~= nil
end

local function rollback(entries)
    for _, entry in ipairs(entries) do
        if not validName(entry.target) and entry.target ~= rolePath then error("Neplatny update journal", 0) end
        local old = fs.combine(backup, entry.target)
        if entry.existed and not fs.exists(old) then error("Chyba zaloha " .. old, 0) end
        if fs.exists(entry.target) then fs.delete(entry.target) end
        if entry.existed then fs.copy(old, entry.target) end
    end
    fs.delete(journal)
end

fs.makeDir("data")
local interrupted = readJournal()
if interrupted then
    print("Obnovujem subory po prerusenej aktualizacii...")
    rollback(interrupted)
end
role = args[1]
if not role and fs.exists(rolePath) then
    local f = assert(fs.open(rolePath, "r"))
    role = f.readAll():match("^%s*(%w+)%s*$")
    f.close()
end
if role ~= "main" and role ~= "client" and role ~= "router" then
    error("Pouzitie: update [main|client|router]. Pri prvej instalacii zadaj ulohu PC.", 0)
end
if fs.exists(stage) then fs.delete(stage) end
fs.makeDir(stage)

local commit = textutils.unserializeJSON(download("https://api.github.com/repos/" .. repo .. "/commits/main"))
if type(commit) ~= "table" or type(commit.sha) ~= "string" or not commit.sha:match("^%x+$") then
    error("Nepodarilo sa zistit verziu repozitara.", 0)
end
local base = "https://raw.githubusercontent.com/" .. repo .. "/" .. commit.sha .. "/oltar/"
local manifest = textutils.unserializeJSON(download(base .. "manifest.json"))
if type(manifest) ~= "table" or manifest.version ~= 1 or type(manifest.files) ~= "table" then
    error("Neplatny manifest", 0)
end
local entries, seen = {}, {}
for _, file in ipairs(manifest.files) do
    if type(file) ~= "table" or not validName(file.source) or not validName(file.target) or type(file.roles) ~= "table" then
        error("Neplatny zaznam manifestu", 0)
    end
    local include = false
    for _, r in ipairs(file.roles) do if r == role then include = true end end
    if include then
        if seen[file.target] then error("Duplicitny ciel: " .. file.target, 0) end
        seen[file.target] = true
        print("Stahujem: " .. file.target)
        local contents = download(base .. file.source)
        local compiled, reason = load(contents, "@" .. file.target, "t", {})
        if not compiled then error("Chyba syntaxe: " .. tostring(reason), 0) end
        local f = fs.open(fs.combine(stage, file.target), "w")
        if not f then error("Neda sa zapisat " .. file.target, 0) end
        f.write(contents); f.close()
        entries[#entries + 1] = { target = file.target, existed = fs.exists(file.target) }
    end
end
if #entries == 0 then error("Manifest neobsahuje subory pre " .. role, 0) end
-- Install the role in the same transaction as the programs; client settings stay untouched.
local roleFile = assert(fs.open(fs.combine(stage, rolePath), "w"))
roleFile.write(role); roleFile.close()
entries[#entries + 1] = { target = rolePath, existed = fs.exists(rolePath) }

-- Everything is downloaded and syntax checked before touching live files.
if fs.exists(backup) then fs.delete(backup) end
fs.makeDir(backup)
for _, entry in ipairs(entries) do
    if entry.existed then fs.copy(entry.target, fs.combine(backup, entry.target)) end
end
local f = fs.open(journal, "w")
if not f then error("Neda sa zapisat journal", 0) end
f.write(textutils.serialize(entries)); f.close()
local installed, installErr = pcall(function()
    for _, entry in ipairs(entries) do
        if fs.exists(entry.target) then fs.delete(entry.target) end
        fs.move(fs.combine(stage, entry.target), entry.target)
    end
end)
if not installed then
    rollback(entries)
    error("Aktualizacia zlyhala, povodne subory obnovene: " .. tostring(installErr), 0)
end
fs.delete(journal)
fs.delete(stage)
print("Aktualizovane: " .. #entries .. " suborov / " .. role .. " / " .. commit.sha:sub(1, 8))
print("Nastavenia klienta zachovane. Automaticky start je nastaveny.")
print("Spusti startup alebo restartuj PC prikazom reboot.")
