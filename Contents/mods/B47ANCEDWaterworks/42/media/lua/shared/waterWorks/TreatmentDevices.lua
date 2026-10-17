local waterWorks=rawget(_G,"waterWorks") or require "waterWorks/API"
local Registry=waterWorks.Registry or require "waterWorks/Registry"
local Infrastructure=waterWorks.Infrastructure or require "waterWorks/Infrastructure"
local Flow=waterWorks.Flow or require "waterWorks/Flow"
local Devices={Definitions={}}
local locks={}

local function authoritative() return not (type(isClient)=="function" and isClient()==true) end
function Devices.registerProvider(definition)
    assert(type(definition)=="table" and type(definition.id)=="string","treatment provider id required")
    assert(type(definition.matches)=="function" and type(definition.describe)=="function","treatment provider callbacks required")
    assert(type(definition.getState)=="function","treatment state callback required")
    assert(not Devices.Definitions[definition.id],"duplicate treatment provider: "..definition.id)
    Devices.Definitions[definition.id]=definition
    return Infrastructure.registerProvider({id=definition.id,kind="treatment",priority=definition.priority,
        matches=definition.matches,describe=definition.describe,getState=definition.getState,
        onAttach=definition.onAttach,onDetach=definition.onDetach})
end
local function consumerFor(store,nodeId)
    local index=store.nodeIndex and store.nodeIndex[nodeId]; local definition=index and Devices.Definitions[index.providerId]
    if not definition or type(definition.getConsumer)~="function" then return nil,"treatment power consumer unavailable" end
    local object,err=Registry.getRuntimeObject(store,nodeId); if not object then return nil,err end
    local ok,value=pcall(definition.getConsumer,object); return ok and value or nil,"treatment power consumer unavailable"
end
function Devices.treat(store,deviceId,targetId,options)
    if not authoritative() then return false,"non-authority" end
    options=type(options)=="table" and options or {}
    if deviceId==targetId then return false,"device and target must differ" end
    local key=tostring(deviceId).."\0"..tostring(targetId); if locks[key] then return false,"treatment route busy" end
    local device,deviceErr=Infrastructure.inspectNode(store,deviceId); if not device then return false,deviceErr end
    local target,targetErr=Infrastructure.inspectNode(store,targetId); if not target then return false,targetErr end
    if device.kind~="treatment" or device.available==false or device.enabled==false then return false,"treatment device unavailable" end
    if target.kind~="storage" and target.kind~="fixture" then return false,"invalid treatment target" end
    local route,routeErr=Flow.findOpenPath(store,deviceId,targetId); if not route then return false,routeErr end
    local treatmentId=tostring(options.treatmentId or device.treatmentId or "")
    if treatmentId=="" or not waterWorks.Treatments[treatmentId] then return false,"unknown treatment" end
    local targetObject=route.target.object
    local inspected=waterWorks.inspectContainer(targetObject); if not inspected then return false,"target water unavailable" end
    local energy=math.max(0,tonumber(device.energyCost) or 0)+math.max(0,tonumber(device.energyPerFluidUnit) or 0)*math.max(0,tonumber(inspected.amount) or 0)
    local operationId=type(options.operationId)=="string" and options.operationId or "waterWorks.deviceTreatment:"..tostring(deviceId)..":"..tostring(targetId)
    local power=(rawget(_G,"B47ANCEDPower") or rawget(_G,"powerWorks")); local consumer=nil
    locks[key]=true
    if energy>0 then
        if not power or type(power.beginEnergyTransaction)~="function" then locks[key]=nil; return false,"treatment energy transaction unavailable" end
        consumer,deviceErr=consumerFor(store,deviceId); if not consumer then locks[key]=nil; return false,deviceErr end
        local reserved,reserveErr=power.beginEnergyTransaction(consumer,energy,operationId)
        if not reserved then locks[key]=nil; return false,reserveErr end
    end
    local ok,result=waterWorks.applyTreatment(targetObject,treatmentId,{operationId=operationId,worldAgeHours=options.worldAgeHours})
    if not ok then
        local restored=energy<=0 or power.rollbackEnergyTransaction(consumer,operationId)==true
        locks[key]=nil; return false,tostring(result)..(restored and "; energy rollback verified" or "; energy recovery inspection required")
    end
    if energy>0 and power.commitEnergyTransaction(consumer,operationId)~=true then
        locks[key]=nil; return false,"treatment committed; energy recovery inspection required"
    end
    locks[key]=nil
    return true,{deviceId=deviceId,targetId=targetId,networkId=route.networkId,treatmentId=treatmentId,
        quality=result,energyConsumed=energy,pathLength=#route.path,operationId=operationId}
end

function Devices.heat(store,deviceId,targetId,options)
    if not authoritative()then return false,"non-authority"end
    options=type(options)=="table"and options or{}
    if deviceId==targetId then return false,"device and target must differ"end
    local key="heat\0"..tostring(deviceId).."\0"..tostring(targetId)
    if locks[key]then return false,"heating route busy"end
    local device,deviceErr=Infrastructure.inspectNode(store,deviceId);if not device then return false,deviceErr end
    local target,targetErr=Infrastructure.inspectNode(store,targetId);if not target then return false,targetErr end
    if device.kind~="treatment"or device.available==false or device.enabled==false then return false,"heating device unavailable"end
    if target.kind~="storage"and target.kind~="fixture"then return false,"invalid heating target"end
    local route,routeErr=Flow.findOpenPath(store,deviceId,targetId,{allowFrozenTarget=true});if not route then return false,routeErr end
    local delta=tonumber(options.deltaC)or tonumber(device.heatDeltaC)
    local maximum=math.max(0,tonumber(device.maxHeatDeltaC)or 20)
    if not delta or delta~=delta or delta<=0 or delta>maximum or delta==math.huge then return false,"invalid heat request"end
    local Thermal=waterWorks.Thermal or require "waterWorks/Thermal"
    local before,thermalErr=Thermal.inspect(store,targetId);if not before then return false,thermalErr end
    local energy=math.max(0,tonumber(device.heatingEnergyCost)or 0)
        +math.max(0,tonumber(device.energyPerDegreeC)or 0)*delta
    local operationId=type(options.operationId)=="string"and options.operationId
        or"waterWorks.deviceHeat:"..tostring(deviceId)..":"..tostring(targetId)
    local power=(rawget(_G,"B47ANCEDPower") or rawget(_G,"powerWorks"));local consumer=nil
    locks[key]=true
    if energy>0 then
        if not power or type(power.beginEnergyTransaction)~="function"then locks[key]=nil;return false,"heating energy transaction unavailable"end
        consumer,deviceErr=consumerFor(store,deviceId);if not consumer then locks[key]=nil;return false,deviceErr end
        local reserved,reserveErr=power.beginEnergyTransaction(consumer,energy,operationId)
        if not reserved then locks[key]=nil;return false,reserveErr end
    end
    local ok,result=Thermal.applyHeat(store,targetId,delta)
    if not ok then
        local restored=energy<=0 or power.rollbackEnergyTransaction(consumer,operationId)==true
        locks[key]=nil;return false,tostring(result)..(restored and"; energy rollback verified"or"; energy recovery inspection required")
    end
    if energy>0 and power.commitEnergyTransaction(consumer,operationId)~=true then
        -- The power outcome is uncertain. Preserve the authoritative thermal
        -- mutation and surface recovery rather than risking duplicate heat.
        locks[key]=nil;return false,"heating committed; energy recovery inspection required"
    end
    locks[key]=nil
    return true,{deviceId=deviceId,targetId=targetId,networkId=route.networkId,
        deltaC=delta,temperatureC=result.temperatureC,frozen=result.frozen,
        energyConsumed=energy,pathLength=#route.path,operationId=operationId,
        previousTemperatureC=before.temperatureC}
end

waterWorks.TreatmentDevices=Devices
waterWorks.registerTreatmentDevice=Devices.registerProvider
waterWorks.treatNetworkContainer=Devices.treat
waterWorks.heatNetworkContainer=Devices.heat
return Devices
