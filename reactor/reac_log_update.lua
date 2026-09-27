local subory = {
 { meno = "log.lua", url = "https://raw.githubusercontent.com/Ballberid/MC-programy/refs/heads/main/reac_log.lua"},
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
