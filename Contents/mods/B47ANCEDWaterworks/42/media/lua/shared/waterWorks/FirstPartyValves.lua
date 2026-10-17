local waterWorks=rawget(_G,"waterWorks") or require "waterWorks/API"
local Registry=waterWorks.Registry or require "waterWorks/Registry"
local Infrastructure=waterWorks.Infrastructure or require "waterWorks/Infrastructure"
local Valves={INLINE_TYPE="waterWorks.InlineShutoffValve",MARKER_KEY="waterWorksInlineValve.v1"}

local function call(object,method,...)
    if not object then return false,nil end
    local ok,fn=pcall(function()return object[method]end)
    if not ok or type(fn)~="function"then return false,nil end
    return pcall(fn,object,...)
end
local function itemFor(object)local ok,item=call(object,"getItem");return ok and item or object end
local function fullType(object)local ok,value=call(itemFor(object),"getFullType");return ok and value or nil end
local function data(object)local ok,value=call(object,"getModData");return ok and type(value)=="table"and value or nil end
local function coordinate(object,name)
    local ok,value=call(object,"get"..name);value=ok and tonumber(value)or nil
    return value and value==value and value~=math.huge and value~=-math.huge and value or nil
end
local function marker(object)
    local md=data(object);local value=md and md[Valves.MARKER_KEY]
    return type(value)=="table"and value.schemaVersion==1 and value or nil
end
local function condition(item)
    local ok,value=call(item,"getCondition");value=ok and tonumber(value)or nil
    local maxOk,maximum=call(item,"getConditionMax");maximum=maxOk and tonumber(maximum)or nil
    if not value or not maximum or maximum<=0 then return 1,100,100 end
    value=math.max(0,math.min(maximum,value));return value/maximum,value,maximum
end
local function sync(object)
    local ok=call(object,"transmitModData")
    if not ok then call(object,"sync")end
end

function Valves.register()
    return Infrastructure.registerProvider({id="waterWorks.inlineValve",kind="valve",priority=200,
        matches=function(object)return fullType(object)==Valves.INLINE_TYPE end,
        describe=function(object)
            local x,y,z=coordinate(object,"X"),coordinate(object,"Y"),coordinate(object,"Z")
            if x==nil or y==nil or z==nil then return nil,"placed valve coordinates unavailable"end
            local value=marker(object)or{};local ok,index=call(object,"getObjectIndex")
            index=ok and tonumber(index)or 0
            return {networkId=tostring(value.networkId or"WATER"),channel="WATER",x=x,y=y,z=z,
                stableKey=table.concat({math.floor(x),math.floor(y),math.floor(z),math.floor(index or 0)},":")}
        end,
        getState=function(object)
            local ratio,current,maximum=condition(itemFor(object));local value=marker(object)or{}
            return {available=ratio>0,enabled=true,open=value.open~=false,condition=current,
                conditionMax=maximum,pressureRating=20+20*ratio,flowLimit=2+6*ratio}
        end,
        validateAction=function(_,action,payload)
            if action~="set-open"or type(payload.open)~="boolean"then return false,"unsupported valve action"end
            return true
        end,
        performAction=function(object,_,payload)
            local md=data(object);local value=marker(object)
            if not md or not value then return false,"valve registration unavailable"end
            value.open=payload.open;sync(object);return true
        end})
end

function Valves.claim(store,object,networkId)
    local md=data(object);if not md then return false,"persistent valve ModData required"end
    if marker(object)then return false,"valve already registered"end
    networkId=tostring(networkId or"WATER")
    if networkId==""or #networkId>128 or networkId:find("[%c]",1)then return false,"valid network id required"end
    md[Valves.MARKER_KEY]={schemaVersion=1,networkId=networkId,open=true}
    local ok,value=Registry.attachObject(store,object)
    if not ok then md[Valves.MARKER_KEY]=nil;return false,value end
    sync(object);return true,value
end

function Valves.inspect(object)
    local value=marker(object);if not value then return nil,"valve is not registered"end
    return {schemaVersion=value.schemaVersion,networkId=value.networkId,open=value.open~=false}
end

Valves.register()
waterWorks.FirstPartyValves=Valves
waterWorks.claimInlineValve=Valves.claim
_G.waterWorks=waterWorks
return Valves
