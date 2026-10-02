local network = {}

function network.open()
    local opened = false
    for _, name in ipairs(peripheral.getNames()) do
        if peripheral.hasType(name, "modem") then
            local ok = pcall(function()
                if not rednet.isOpen(name) then rednet.open(name) end
            end)
            if ok then opened = true end
        end
    end
    if not opened then return false, "modem_missing" end
    return true
end

return network
