local waterWorks=rawget(_G,"waterWorks") or require "waterWorks/API"
local Infrastructure=waterWorks.Infrastructure or require "waterWorks/Infrastructure"
local Registry=waterWorks.Registry or require "waterWorks/Registry"
local PumpPower={}
local definitions={}

function PumpPower.registerProvider(definition)
    assert(type(definition)=="table" and type(definition.id)=="string","pump provider id required")
    assert(type(definition.matches)=="function" and type(definition.describe)=="function","pump callbacks required")
    assert(type(definition.getConsumer)=="function","pump power consumer callback required")
    definitions[definition.id]=definition
    return Infrastructure.registerProvider({id=definition.id,kind="pump",priority=definition.priority,
        matches=definition.matches,describe=definition.describe,onAttach=definition.onAttach,onDetach=definition.onDetach,
        getState=function(object)
            local consumer=definition.getConsumer(object)
            local power=(rawget(_G,"B47ANCEDPower") or rawget(_G,"powerWorks"))
            local powerState=power and type(power.getConsumerPowerState)=="function"
                and power.getConsumerPowerState(consumer) or nil
            local state=type(definition.getState)=="function" and definition.getState(object) or {}
            state=type(state)=="table" and state or {}
            state.powered=powerState and powerState.known==true and powerState.powered==true or false
            if not powerState or powerState.known~=true then state.fault="power state unavailable" end
            state.powerDemand=tonumber(state.powerDemand) or tonumber(definition.powerDemand) or 0
            state.energyPerFluidUnit=tonumber(state.energyPerFluidUnit) or tonumber(definition.energyPerFluidUnit) or 0
            return state
        end,
        validateAction=definition.validateAction,performAction=definition.performAction})
end

function PumpPower.getConsumer(store,nodeId)
    local index=type(store)=="table" and type(store.nodeIndex)=="table" and store.nodeIndex[nodeId] or nil
    local definition=index and definitions[index.providerId] or nil
    if not definition then return nil,"pump power provider unavailable" end
    local object,err=Registry.getRuntimeObject(store,nodeId); if not object then return nil,err end
    local ok,consumer=pcall(definition.getConsumer,object)
    if not ok or not consumer then return nil,"pump consumer unavailable" end
    return consumer
end

waterWorks.PumpPower=PumpPower
waterWorks.registerPowerWorksPump=PumpPower.registerProvider
PumpPower.Definitions=definitions
_G.waterWorks=waterWorks
return PumpPower
