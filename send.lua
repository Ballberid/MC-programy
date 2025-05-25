local sprava = ...
local ID1 = 2
local ID2 = 3

rednet.open("left")

rednet.send(ID1, sprava)
rednet.send(ID2, sprava)
