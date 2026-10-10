-- Updates run only in the worker's execution loop, after returning to its dock.
local nav=require("navigation")
local updater={}
function updater.new(client)
    local state=client.state
    local self={}
    function self.report()
        if state.update then client.send("update_result",require("fleet_store").copy(state.update)) end
    end
    if state.update and state.update.phase=="rebooting" then
        state.status=state.update.returnStatus or "idle"
        state.update.phase="complete"; client.save()
    elseif state.update and state.update.phase=="updating" then
        state.status=state.update.returnStatus or "idle"
        state.update.phase,state.update.error="failed","update_interrupted"; client.save()
    elseif state.update and state.update.phase=="returning" and state.task and nav.getPosition()
        and nav.distance(nav.getPosition(),state.dock)>0 then
        client.queued,client.recovery,client.retry=true,true,false
    end
    local function fail(reason)
        state.update.phase,state.update.error="failed",tostring(reason)
        client.save(); self.report(); client.status(true)
    end
    function self.request(packet)
        if type(packet.request)~="string" then return end
        if state.update and state.update.request==packet.request then self.report(); return end
        state.update={request=packet.request,phase="returning"}
        client.save(); self.report()
        if state.status=="running" or state.status=="assigned" or client.queued then
            client.cancel,client.paused=true,false
        elseif nav.getPosition() and nav.distance(nav.getPosition(),state.dock)>0 then
            if not state.task then fail("update_requires_dock"); return end
            client.queued,client.recovery,client.retry=true,true,false
        end
    end
    function self.tick()
        if not state.update or state.update.phase~="returning" or client.queued
            or state.status=="running" or state.status=="assigned" then return end
        local synced,err=nav.sync()
        if not synced then fail(err); return end
        if nav.distance(nav.getPosition(),state.dock)~=0 then fail("update_return_failed"); return end
        client.clearClaims()
        state.update.returnStatus=state.status
        state.update.phase="updating"; client.save(); self.report(); client.status(true)
        local ran,ok=pcall(shell.run,"update","turtle")
        if not ran or not ok then fail(ran and "update_failed" or ok); return end
        -- startup.lua uses the saved pairing, including PCs other than #16.
        state.update.phase="rebooting"; client.save(); self.report()
        os.reboot()
    end
    return self
end
return updater
