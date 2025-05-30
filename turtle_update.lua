local subory = {
 { meno = "GoHome.lua", url = "https://raw.githubusercontent.com/Ballberid/MC-programy/refs/heads/main/GoHome.lua"},
 { meno = "GoBack.lua", url = "https://raw.githubusercontent.com/Ballberid/MC-programy/refs/heads/main/GoBack.lua"},
 { meno = "send.lua", url = "https://raw.githubusercontent.com/Ballberid/MC-programy/refs/heads/main/send.lua"},
 { meno = "fill.lua", url = "https://raw.githubusercontent.com/Ballberid/MC-programy/refs/heads/main/fill.lua"},
 { meno = "refuel.lua", url = "https://raw.githubusercontent.com/Ballberid/MC-programy/refs/heads/main/refuel.lua"},
 { meno = "unload.lua", url = "https://raw.githubusercontent.com/Ballberid/MC-programy/refs/heads/main/unload.lua"},
 { meno = "parcela.lua", url = "https://raw.githubusercontent.com/Ballberid/MC-programy/refs/heads/main/parcela.lua"},
}

for _, subor in ipairs(subory) do
  print("Stahujem: "..subor.meno)
  local r = http.get(subor.url)
  if r then
    local obsah = r.readAll()
    r.close()
    local f = fs.open(subor.meno, "w")
    f.write(obsah)
    f.close()
    print("Program "..subor.meno.." bol aktualizovany.")
  else
    print("Program "..subor.meno.." sa nepodarilo stiahnut.")
  end
end

print("Aktualizacia dokoncena.")
