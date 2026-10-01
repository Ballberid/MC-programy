local url = "https://raw.githubusercontent.com/Ballberid/MC-programy/refs/heads/main/turtle_update.lua"
local r = http.get(url)

if r then
  local obsah = r.readAll()
  r.close()
  local f = fs.open("update.lua", "w")
    f.write(obsah)
    f.close()
    print("Update programu update.lua dokonceny.")
  else
    print("Nepodarilo sa stiahnut program")
  end
