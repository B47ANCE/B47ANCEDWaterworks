local waterWorks=rawget(_G,"waterWorks") or require "waterWorks/API"
local PumpPower=waterWorks.PumpPower or require "waterWorks/PumpPower"
local FirstPartyPumps={PORTABLE_TYPE="waterWorks.PortableTransferPump"}

local function call(object,method,...)
    if not object then return false,nil end
    local ok,fn=pcall(function() return object[method] end)
    if not ok or type(fn)~="function" then return false,nil end
    return pcall(fn,object,...)
end
local function itemFor(object)
    local ok,item=call(object,"getItem")
    if ok and item then return item end
    return object
end
local function fullType(item)
    local ok,value=call(item,"getFullType")
    return ok and type(value)=="string" and value or nil
end
local function coordinate(object,name)
    local ok,value=call(object,"get"..name)
    value=ok and tonumber(value) or nil
    return value and value==value and value~=math.huge and value~=-math.huge and value or nil
end
local function data(object)
    local ok,value=call(object,"getModData")
    return ok and type(value)=="table" and value or nil
end
local function condition(item)
    local ok,value=call(item,"getCondition");value=ok and tonumber(value)or nil
    local maxOk,maximum=call(item,"getConditionMax");maximum=maxOk and tonumber(maximum)or nil
    if not value or not maximum or maximum<=0 then return 1,100,100 end
    value=math.max(0,math.min(maximum,value));return value/maximum,value,maximum
end

function FirstPartyPumps.register()
    local power=(rawget(_G,"B47ANCEDPower") or rawget(_G,"powerWorks"))
    if power and type(power.registerConsumer)=="function" and not power.getConsumerProfile(FirstPartyPumps.PORTABLE_TYPE) then
        power.registerConsumer({item=FirstPartyPumps.PORTABLE_TYPE,sizes={"PACK"},storageMode="modData",
            referenceCapacity=15,baseUseDelta=0,installTime=180,removeTime=150,provider="waterWorksPump"})
    end
    return PumpPower.registerProvider({id="waterWorks.portablePump",priority=200,
        matches=function(object) return fullType(itemFor(object))==FirstPartyPumps.PORTABLE_TYPE end,
        describe=function(object)
            local x,y,z=coordinate(object,"X"),coordinate(object,"Y"),coordinate(object,"Z")
            if x==nil or y==nil or z==nil then return nil,"placed pump coordinates unavailable" end
            local md=data(object) or {}; local network=tostring(md.waterWorksNetworkId or "WATER")
            local ok,index=call(object,"getObjectIndex"); index=ok and tonumber(index) or 0
            return {networkId=network,channel="WATER",x=x,y=y,z=z,
                stableKey=table.concat({math.floor(x),math.floor(y),math.floor(z),math.floor(index or 0)},":")}
        end,
        getConsumer=itemFor,
        getState=function(object)
            local item=itemFor(object);local md=data(object) or {};local ratio,current,maximum=condition(item)
            return {enabled=md.waterWorksPumpEnabled~=false,available=ratio>0,condition=current,conditionMax=maximum,
                pressure=10+15*ratio,flowLimit=1+5*ratio,powerDemand=1,
                energyPerFluidUnit=0.05+(1-ratio)*0.03}
        end})
end

FirstPartyPumps.register()
waterWorks.FirstPartyPumps=FirstPartyPumps
_G.waterWorks=waterWorks
return FirstPartyPumps
