-- Explicit recovery after a turtle has been broken and placed in a new dock.
-- Run with the old worker stopped: worker_reset [controller ID] [direction 0..3].
local args={...}
if not turtle then error("Spusti na turtle v novom doku.",0) end
local store=require("fleet_store")
local config=require("config")
local previous=store.load("data/worker-state.txt",{})
local controller=tonumber(args[1]) or previous.controller or 16
if controller<0 or controller%1~=0 then error("Neplatne ID hlavneho PC.",0) end
local direction=args[2] and tonumber(args[2])
if direction==nil then
    direction=require("fleet_dialog").number("Smer do chodby: 0 sever -Z, 1 vychod +X, 2 juh +Z, 3 zapad -X",nil,0,3)
end
if not config.isDirection(direction) then error("Neplatny smer.",0) end
local opened,err=require("network").open(); if not opened then error(err,0) end
local ok,reason=require("navigation").init(direction); if not ok then error(reason,0) end
local dock=require("navigation").getPosition()
local c=store.copy(previous.previous or config.load() or config.defaults())
c.start,c.home=store.copy(dock),store.copy(dock)
store.save("data/worker-before-reset.txt",previous)
local saved,saveErr=config.save(c); if not saved then error(saveErr,0) end
local serial=(previous.rebindSerial or 0)+1
store.save("data/worker-state.txt",{version=1,controller=controller,dock=dock,status="idle",seen={},
    registration=tostring(os.getComputerID())..":"..os.epoch("utc")..":"..serial,
    rebindSerial=serial,rebindPending=true})
print("Novy dok: "..dock.x..","..dock.y..","..dock.z.."; smer "..direction)
print("Stara uloha zrusena lokalne. Worker poziada PC o nove priradenie a uvolnenie svojich rezervacii.")
print("Spusti worker "..controller.." alebo reboot. Hlavny PC musi mat aktualny kod.")
