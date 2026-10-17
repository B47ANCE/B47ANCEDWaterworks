local waterWorks=rawget(_G,"waterWorks") or {}
local Registry=waterWorks.Registry or require "waterWorks/Registry"
local Infrastructure=waterWorks.Infrastructure or require "waterWorks/Infrastructure"
local Vanilla={MARKER_KEY="waterWorksInfrastructure.v1"}

local function authoritative()
    return not (type(isClient)=="function" and isClient()==true)
end
local function call(object,method,...)
    if not object then return false,nil end
    local ok,fn=pcall(function() return object[method] end)
    if not ok or type(fn)~="function" then return false,nil end
    return pcall(fn,object,...)
end
local function modData(object)
    local ok,value=call(object,"getModData")
    return ok and type(value)=="table" and value or nil
end
local function marker(object)
    local data=modData(object); local value=data and data[Vanilla.MARKER_KEY]
    return type(value)=="table" and value.schemaVersion==1 and value or nil
end
local function fluid(object)
    local ok,value=call(object,"getFluidContainer"); return ok and value or nil
end
local function coordinate(object,key)
    local ok,value=call(object,"get"..key:upper()); value=ok and tonumber(value) or nil
    return value and math.floor(value) or nil
end
local function stableKey(object)
    local x,y,z=coordinate(object,"x"),coordinate(object,"y"),coordinate(object,"z")
    if x==nil or y==nil or z==nil then return nil,"world coordinates unavailable" end
    local _,sprite=call(object,"getSpriteName")
    local _,index=call(object,"getObjectIndex")
    index=tonumber(index)
    if not index or index<0 then return nil,"world object index unavailable" end
    sprite=tostring(sprite or "object"):gsub("[^%w_.%-]","_")
    return table.concat({x,y,z,sprite,math.floor(index)},":"),x,y,z
end
local function inferKind(container,object)
    local ok,external=call(object,"getUsesExternalWaterSource")
    if ok and external==true then return "fixture" end
    ok,external=call(object,"hasExternalWaterSource")
    if ok and external==true then return "fixture" end
    local rainOk,rain=call(container,"getRainCatcher")
    if rainOk and (tonumber(rain) or 0)>0 then return "source" end
    local sourceOk,source=call(container,"isWaterSource")
    if sourceOk and source==true then return "source" end
    return "storage"
end

for _,kind in ipairs({"source","storage","fixture"}) do
    Infrastructure.registerProvider({id="waterWorks.vanilla."..kind,kind=kind,priority=100,
        matches=function(object)
            local value=marker(object)
            return value~=nil and value.kind==kind and fluid(object)~=nil
        end,
        describe=function(object)
            local value=marker(object)
            return value and {networkId=value.networkId,stableKey=value.stableKey,channel=value.channel,
                x=value.x,y=value.y,z=value.z} or nil
        end,
        getState=function(object)
            local container=fluid(object); if not container then return {available=false,fault="container unavailable"} end
            local amountOk,amount=call(container,"getAmount"); local capacityOk,capacity=call(container,"getCapacity")
            local inputOk,inputLocked=call(container,"isInputLocked")
            return {available=amountOk and capacityOk,amount=amount,capacity=capacity,
                enabled=not (inputOk and inputLocked==true),quality=waterWorks.getQuality and waterWorks.getQuality(object) or nil}
        end})
end

function Vanilla.claimObject(store,object,networkId,requestedKind)
    if not authoritative() then return false,"non-authority" end
    if type(networkId)~="string" or networkId=="" or #networkId>128 then return false,"valid network id required" end
    local container=fluid(object); if not container then return false,"verified FluidContainer required" end
    local data=modData(object); if not data then return false,"persistent object ModData required" end
    if data[Vanilla.MARKER_KEY]~=nil then return false,"object already claimed" end
    local key,x,y,z=stableKey(object); if not key then return false,x end
    local kind=requestedKind or inferKind(container,object)
    if kind~="source" and kind~="storage" and kind~="fixture" then return false,"unsupported vanilla role" end
    data[Vanilla.MARKER_KEY]={schemaVersion=1,networkId=networkId,stableKey=key,kind=kind,
        channel="WATER",x=x,y=y,z=z}
    local attached,result=Registry.attachObject(store,object)
    if not attached then data[Vanilla.MARKER_KEY]=nil; return false,result end
    local synced=call(object,"transmitModData")
    if not synced then call(object,"sync") end
    return true,result
end

function Vanilla.reattachClaimedObject(store,object)
    if not marker(object) then return false,"object is not claimed" end
    return Registry.attachObject(store,object)
end

function Vanilla.inspectClaim(object)
    local value=marker(object); if not value then return nil,"object is not claimed" end
    local result={}; for key,entry in pairs(value) do result[key]=entry end; return result
end

waterWorks.VanillaProviders=Vanilla
waterWorks.claimVanillaInfrastructure=Vanilla.claimObject
_G.waterWorks=waterWorks
return Vanilla
