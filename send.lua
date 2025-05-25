local sprava = ...
local ID1 = 2
local ID2 = 3

rednet.open("left")

rednet.send(ID1, text)
rednet.send(ID2, text)
