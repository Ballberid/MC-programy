-- Optional Rednet range extender on a separate modem-equipped computer.
local network = require("network")
local ok, err = network.open()
if not ok then error(err, 0) end
print("Rednet opakovac bezi. Ukoncit: Ctrl+T")
shell.run("repeat")
