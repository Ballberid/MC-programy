local model=require("fleet_model")
local pool={}
function pool.acquire(locks,owner,token)
    for _,key in ipairs({"tunnel","tunnel:up:1","tunnel:up:2","tunnel:down"}) do
        if locks[key] then return false,"occupied" end
    end
    for index=1,9 do
        local key="tunnel:lane:"..index; local held=locks[key]
        if held and held.owner==owner then return true,nil,key,held.token end
    end
    for index=1,9 do
        local key="tunnel:lane:"..index
        if not locks[key] then
            local ok,err=model.acquire(locks,key,owner,token)
            if ok then return true,nil,key,token end
            return false,err
        end
    end
    return false,"occupied"
end
return pool
