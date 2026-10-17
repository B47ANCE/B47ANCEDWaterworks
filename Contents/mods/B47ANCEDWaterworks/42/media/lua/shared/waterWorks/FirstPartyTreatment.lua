local waterWorks=rawget(_G,"waterWorks") or require "waterWorks/API"
local Devices=waterWorks.TreatmentDevices or require "waterWorks/TreatmentDevices"
local Treatment={PURIFIER_TYPE="waterWorks.ElectricWaterPurifier"}

local function call(object,method,...)
    if not object then return false,nil end
    local ok,fn=pcall(function()return object[method]end)
    if not ok or type(fn)~="function"then return false,nil end
    return pcall(fn,object,...)
end
local function itemFor(object)local ok,item=call(object,"getItem");return ok and item or object end
local function fullType(object)local ok,value=call(itemFor(object),"getFullType");return ok and value or nil end
local function coordinate(object,name)local ok,value=call(object,"get"..name);value=ok and tonumber(value)or nil
    return value and value==value and value~=math.huge and value~=-math.huge and value or nil end
local function data(object)local ok,value=call(object,"getModData");return ok and type(value)=="table"and value or nil end
local function condition(item)
    local ok,value=call(item,"getCondition");value=ok and tonumber(value)or nil
    local maxOk,maximum=call(item,"getConditionMax");maximum=maxOk and tonumber(maximum)or nil
    if not value or not maximum or maximum<=0 then return 1,100,100 end
    value=math.max(0,math.min(maximum,value));return value/maximum,value,maximum
end

function Treatment.register()
    local power=(rawget(_G,"B47ANCEDPower") or rawget(_G,"powerWorks"))
    if power and type(power.registerConsumer)=="function"
        and not power.getConsumerProfile(Treatment.PURIFIER_TYPE)then
        power.registerConsumer({item=Treatment.PURIFIER_TYPE,sizes={"PACK"},storageMode="modData",
            referenceCapacity=15,baseUseDelta=0,installTime=180,removeTime=150,
            provider="waterWorksTreatment"})
    end
    return Devices.registerProvider({id="waterWorks.electricPurifier",priority=200,
        matches=function(object)return fullType(object)==Treatment.PURIFIER_TYPE end,
        describe=function(object)
            local x,y,z=coordinate(object,"X"),coordinate(object,"Y"),coordinate(object,"Z")
            if x==nil or y==nil or z==nil then return nil,"placed purifier coordinates unavailable"end
            local md=data(object)or{};local network=tostring(md.waterWorksNetworkId or"WATER")
            local ok,index=call(object,"getObjectIndex");index=ok and tonumber(index)or 0
            return {networkId=network,channel="WATER",x=x,y=y,z=z,
                stableKey=table.concat({math.floor(x),math.floor(y),math.floor(z),math.floor(index or 0)},":")}
        end,
        getConsumer=itemFor,
        getState=function(object)
            local item=itemFor(object);local md=data(object)or{};local ratio,current,maximum=condition(item)
            return {enabled=md.waterWorksTreatmentEnabled~=false,available=ratio>0,
                condition=current,conditionMax=maximum,treatmentId="boiled",
                energyCost=0.25,energyPerFluidUnit=0.08,heatDeltaC=5,maxHeatDeltaC=20,
                heatingEnergyCost=0.25,energyPerDegreeC=0.1}
        end})
end

Treatment.register()
waterWorks.FirstPartyTreatment=Treatment
_G.waterWorks=waterWorks
return Treatment
