local waterWorks=rawget(_G,"waterWorks") or {}
local Registry=waterWorks.Registry or require "waterWorks/Registry"
local Infrastructure={MAX_ACTION_ID=64}
local contracts={}
local locks={}
local KINDS={source=true,storage=true,fixture=true,valve=true,pump=true,junction=true,treatment=true,filter=true,meter=true}

local function authoritative()
    return not (type(isClient)=="function" and isClient()==true)
end
local function finite(value)
    return type(value)=="number" and value==value and value~=math.huge and value~=-math.huge
end
local function nonnegative(value)
    value=tonumber(value); return finite(value) and math.max(0,value) or nil
end
local function normalizeState(kind,value)
    value=type(value)=="table" and value or {}
    local result={schemaVersion=1,kind=kind,available=value.available~=false,enabled=value.enabled~=false,
        fault=tostring(value.fault or "")}
    for _,key in ipairs({"amount","capacity","demand","supply","pressure","pressureRating","flowLimit",
        "powerDemand","energyPerFluidUnit","energyCost","condition","conditionMax","heatDeltaC",
        "maxHeatDeltaC","heatingEnergyCost","energyPerDegreeC","remainingCapacity","filterCapacity",
        "flowMultiplier"}) do
        result[key]=nonnegative(value[key])
    end
    if type(value.treatmentId)=="string" and value.treatmentId~="" then result.treatmentId=value.treatmentId end
    if type(value.filterId)=="string" and value.filterId~="" then result.filterId=value.filterId end
    if kind=="filter"then
        result.replaceableMedia=value.replaceableMedia==true
        result.batchFilter=value.batchFilter==true
        result.exhausted=value.exhausted==true or result.remainingCapacity~=nil and result.remainingCapacity<=0
        if result.flowMultiplier~=nil then result.flowMultiplier=math.min(1,result.flowMultiplier)end
    end
    if kind=="valve" then result.open=value.open~=false end
    if kind=="pump" then
        if type(value.powered)=="boolean" then result.powered=value.powered else result.powered=nil end
    end
    if value.quality then result.quality=waterWorks.normalizeQuality and waterWorks.normalizeQuality(value.quality) or value.quality end
    return result
end
local function getIndex(store,nodeId)
    if type(store)~="table" or type(store.nodeIndex)~="table" then return nil,"registry store required" end
    local index=store.nodeIndex[nodeId]; if not index then return nil,"unknown node" end
    local network=store.networks and store.networks[index.networkId]
    local node=network and network.nodes and network.nodes[nodeId]
    if not node then return nil,"orphan node index" end
    local contract=contracts[index.providerId]
    if not contract then return nil,"provider contract unavailable" end
    return {index=index,network=network,node=node,contract=contract}
end

function Infrastructure.registerProvider(definition)
    assert(type(definition)=="table" and type(definition.id)=="string","provider id required")
    assert(type(definition.kind)=="string" and KINDS[definition.kind],"supported infrastructure kind required")
    assert(type(definition.matches)=="function" and type(definition.describe)=="function","provider callbacks required")
    assert(not contracts[definition.id],"duplicate infrastructure provider: "..definition.id)
    local contract={id=definition.id,kind=definition.kind,getState=definition.getState,
        validateAction=definition.validateAction,performAction=definition.performAction}
    Registry.registerProvider({id=definition.id,priority=definition.priority,matches=definition.matches,
        describe=function(object)
            local descriptor=definition.describe(object)
            if type(descriptor)~="table" then return descriptor end
            descriptor.kind=definition.kind
            return descriptor
        end,onAttach=definition.onAttach,onDetach=definition.onDetach})
    contracts[definition.id]=contract
    return contract
end

function Infrastructure.inspectNode(store,nodeId,context)
    local resolved,err=getIndex(store,nodeId); if not resolved then return nil,err end
    local object,objectErr=Registry.getRuntimeObject(store,nodeId)
    if not object then return nil,objectErr or "node not loaded" end
    local value={}
    if type(resolved.contract.getState)=="function" then
        local ok,result=pcall(resolved.contract.getState,object,resolved.node,context or {})
        if not ok or type(result)~="table" then return nil,"provider state failed" end
        value=result
    end
    local state=normalizeState(resolved.contract.kind,value)
    state.nodeId=nodeId; state.networkId=resolved.index.networkId; state.providerId=resolved.index.providerId
    return state
end

function Infrastructure.requestAction(store,nodeId,actionId,payload,context)
    if not authoritative() then return false,"non-authority" end
    if type(actionId)~="string" or actionId=="" or #actionId>Infrastructure.MAX_ACTION_ID
        or actionId:find("[%c]",1) then return false,"valid action id required" end
    if type(payload)~="table" then return false,"serializable action payload required" end
    local resolved,err=getIndex(store,nodeId); if not resolved then return false,err end
    if locks[nodeId] then return false,"node busy" end
    local object,objectErr=Registry.getRuntimeObject(store,nodeId)
    if not object then return false,objectErr or "node not loaded" end
    if type(resolved.contract.performAction)~="function" then return false,"provider is read-only" end
    if type(resolved.contract.validateAction)=="function" then
        local ok,allowed,reason=pcall(resolved.contract.validateAction,object,actionId,payload,context or {},resolved.node)
        if not ok then return false,"provider validation failed" end
        if allowed~=true then return false,reason or "action rejected" end
    end
    locks[nodeId]=actionId
    local called,result,reason=pcall(resolved.contract.performAction,object,actionId,payload,context or {},resolved.node)
    locks[nodeId]=nil
    if not called then return false,"provider action failed" end
    if result~=true then return false,reason or "action rejected" end
    local state,stateErr=Infrastructure.inspectNode(store,nodeId,context)
    if not state then return false,"action committed but state unavailable: "..tostring(stateErr) end
    return true,state
end

function Infrastructure.getKinds()
    local result={}; for kind in pairs(KINDS) do result[#result+1]=kind end; table.sort(result); return result
end

Infrastructure.Contracts=contracts
waterWorks.Infrastructure=Infrastructure
waterWorks.registerInfrastructureProvider=Infrastructure.registerProvider
waterWorks.inspectInfrastructureNode=Infrastructure.inspectNode
waterWorks.requestInfrastructureAction=Infrastructure.requestAction
_G.waterWorks=waterWorks
return Infrastructure
