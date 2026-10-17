local waterWorks=rawget(_G,"waterWorks") or require "waterWorks/API"
local Iteration=require "waterWorks/Iteration"
local Registry=waterWorks.Registry or require "waterWorks/Registry"
local Thermal={SCHEMA_VERSION=1,DEFAULT_BUDGET=8,MAX_ENTRIES=65536,MAX_ELAPSED_HOURS=24,
    DEFAULT_RESPONSE_PER_HOUR=.2,FREEZE_C=0,THAW_C=1}
local cursors=setmetatable({},{__mode="k"})

local function authoritative() return not(type(isClient)=="function" and isClient()==true)end
local function finite(v)return type(v)=="number"and v==v and v~=math.huge and v~=-math.huge end
local function count(t)local n=0;for _ in pairs(t)do n=n+1 end;return n end
local function state(store,create)
    if type(store)~="table"then return nil,"registry store required"end
    if store.thermalState==nil and create then store.thermalState={schemaVersion=Thermal.SCHEMA_VERSION,revision=0,entries={}}end
    local value=store.thermalState
    if type(value)~="table"or value.schemaVersion~=Thermal.SCHEMA_VERSION or type(value.entries)~="table"then return nil,"unsupported thermal schema"end
    return value
end
local function copy(e)
    if not e then return nil end
    return{nodeId=e.nodeId,temperatureC=e.temperatureC,frozen=e.frozen,lastProcessedHour=e.lastProcessedHour,
        responsePerHour=e.responsePerHour,lastAmbientC=e.lastAmbientC,lastError=e.lastError}
end

function Thermal.set(store,nodeId,definition)
    if not authoritative()then return false,"non-authority"end
    local s,err=state(store,true);if not s then return false,err end
    definition=type(definition)=="table"and definition or {};local temperature=tonumber(definition.temperatureC)
    local response=tonumber(definition.responsePerHour)or Thermal.DEFAULT_RESPONSE_PER_HOUR
    if type(nodeId)~="string"or nodeId==""or not finite(temperature)or temperature< -100 or temperature>200
        or not finite(response)or response<=0 or response>1 then return false,"invalid thermal state"end
    if not s.entries[nodeId]and count(s.entries)>=Thermal.MAX_ENTRIES then return false,"thermal limit reached"end
    s.entries[nodeId]={nodeId=nodeId,temperatureC=temperature,frozen=definition.frozen==true or temperature<=Thermal.FREEZE_C,
        lastProcessedHour=tonumber(definition.lastProcessedHour),responsePerHour=response,lastAmbientC=nil,lastError=nil}
    s.revision=s.revision+1;return true,copy(s.entries[nodeId])
end

function Thermal.applyHeat(store,nodeId,deltaC)
    if not authoritative()then return false,"non-authority"end
    local s,err=state(store,false);if not s then return false,err end
    local e=s.entries[nodeId];deltaC=tonumber(deltaC)
    if not e then return false,"thermal state unavailable"end
    if not finite(deltaC)or deltaC==0 or math.abs(deltaC)>200 then return false,"invalid heat delta"end
    e.temperatureC=math.max(-100,math.min(200,e.temperatureC+deltaC))
    if e.frozen and e.temperatureC>=Thermal.THAW_C then e.frozen=false elseif not e.frozen and e.temperatureC<=Thermal.FREEZE_C then e.frozen=true end
    e.lastError=nil;s.revision=s.revision+1;return true,copy(e)
end

function Thermal.step(store,worldHour,budget,ambientResolver)
    if not authoritative()then return false,"non-authority"end
    local s,err=state(store,false);if not s then return false,err end
    worldHour=tonumber(worldHour);budget=math.max(1,math.min(128,math.floor(tonumber(budget)or Thermal.DEFAULT_BUDGET)))
    if not finite(worldHour)then return false,"world hour required"end
    local cursor=cursors[store];local inspected,changed=0,0
    while inspected<budget do
        local id,e=Iteration.nextEntry(s.entries,cursor);cursor=id;if not id then cursor=nil;break end
        inspected=inspected+1;local previous=tonumber(e.lastProcessedHour)or worldHour;e.lastProcessedHour=worldHour
        local elapsed=math.max(0,math.min(Thermal.MAX_ELAPSED_HOURS,worldHour-previous))
        if elapsed>0 then
            local object=Registry.getRuntimeObject(store,id)
            if object then
                local ok,ambient=pcall(ambientResolver or waterWorks.resolveAmbientTemperature,object,id)
                ambient=ok and tonumber(ambient)or nil
                if finite(ambient)then
                    local factor=math.min(1,e.responsePerHour*elapsed);local before=e.temperatureC
                    e.temperatureC=before+(ambient-before)*factor;e.lastAmbientC=ambient;e.lastError=nil
                    if e.frozen and e.temperatureC>=Thermal.THAW_C then e.frozen=false elseif not e.frozen and e.temperatureC<=Thermal.FREEZE_C then e.frozen=true end
                    if e.temperatureC~=before then changed=changed+1 end
                else e.lastError="ambient temperature unavailable"end
            else e.lastError="node not loaded"end
        end
    end
    if inspected>0 then s.revision=s.revision+1 end;cursors[store]=cursor
    return true,{inspected=inspected,changed=changed,revision=s.revision,cursor=cursor}
end

function Thermal.inspect(store,nodeId)
    local s,err=state(store,false);if not s then return nil,err end
    local e=s.entries[nodeId];if not e then return nil,"thermal state unavailable"end
    return copy(e)
end
function Thermal.isFrozen(store,nodeId)local e=Thermal.inspect(store,nodeId);return e and e.frozen==true or false end

waterWorks.resolveAmbientTemperature=waterWorks.resolveAmbientTemperature or function()
    if type(getClimateManager)~="function"then return nil end
    local ok,manager=pcall(getClimateManager);if not ok or not manager then return nil end
    local called,value=pcall(function()return manager:getTemperature()end);return called and value or nil
end
waterWorks.Thermal=Thermal
waterWorks.inspectThermalState=Thermal.inspect
_G.waterWorks=waterWorks
return Thermal
