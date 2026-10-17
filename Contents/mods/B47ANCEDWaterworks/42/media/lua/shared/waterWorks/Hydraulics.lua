local waterWorks=rawget(_G,"waterWorks") or {}
local Iteration=require "waterWorks/Iteration"
local Network=waterWorks.Network or require "waterWorks/Network"
local Registry=waterWorks.Registry or require "waterWorks/Registry"
local Infrastructure=waterWorks.Infrastructure or require "waterWorks/Infrastructure"
local Hydraulics={}
local jobs=setmetatable({},{__mode="k"})
local published=setmetatable({},{__mode="k"})

local function finite(value) return type(value)=="number" and value==value and value~=math.huge and value~=-math.huge end
local function nonnegative(value) return finite(value) and math.max(0,value) or nil end
local function runtimeFor(registry,root)
    local value=root[registry]; if not value then value={}; root[registry]=value end; return value
end
local function component(result,id)
    local value=result[id]
    if not value then
        value={componentId=id,nodeCount=0,loadedCount=0,unavailableCount=0,sourceCount=0,storageCount=0,
            fixtureCount=0,pumpCount=0,unpoweredPumpCount=0,unknownPowerPumpCount=0,closedValveCount=0,
            supply=0,demand=0,storedAmount=0,storageCapacity=0,pressureCeiling=nil}
        result[id]=value
    end
    return value
end
local function addState(target,state)
    target.loadedCount=target.loadedCount+1
    if state.available==false then target.unavailableCount=target.unavailableCount+1 end
    if state.kind=="source" then
        target.sourceCount=target.sourceCount+1
        target.supply=target.supply+(nonnegative(state.supply) or nonnegative(state.flowLimit) or nonnegative(state.amount) or 0)
    elseif state.kind=="storage" then
        target.storageCount=target.storageCount+1
        target.storedAmount=target.storedAmount+(nonnegative(state.amount) or 0)
        target.storageCapacity=target.storageCapacity+(nonnegative(state.capacity) or 0)
    elseif state.kind=="fixture" then
        target.fixtureCount=target.fixtureCount+1
        target.demand=target.demand+(nonnegative(state.demand) or 0)
    elseif state.kind=="pump" then
        target.pumpCount=target.pumpCount+1
        target.demand=target.demand+(nonnegative(state.demand) or 0)
        if state.powered==false then target.unpoweredPumpCount=target.unpoweredPumpCount+1
        elseif state.powered==nil then target.unknownPowerPumpCount=target.unknownPowerPumpCount+1 end
    elseif state.kind=="valve" and state.open==false then target.closedValveCount=target.closedValveCount+1 end
    local pressure=nonnegative(state.pressure)
    if pressure and (state.kind~="pump" or state.powered==true) then
        target.pressureCeiling=math.max(target.pressureCeiling or 0,pressure)
    end
end
local function finalize(target)
    target.availableSupply=target.supply+target.storedAmount
    target.deficit=math.max(0,target.demand-target.availableSupply)
    target.supplyRatio=target.demand>0 and math.min(1,target.availableSupply/target.demand)
        or (target.availableSupply>0 and 1 or 0)
    target.reliable=target.unavailableCount==0 and target.closedValveCount==0 and target.unknownPowerPumpCount==0
    target.estimatedPressure=target.reliable and target.pressureCeiling and target.pressureCeiling*target.supplyRatio or nil
end
local function start(store,networkId,network)
    local job={revision=network.revision,cursor=nil,nodeIds={},phase="discover",index=1,components={}}
    runtimeFor(store,jobs)[networkId]=job
    return job
end

function Hydraulics.step(store,networkId,budget,context)
    if type(store)~="table" or type(store.networks)~="table" then return nil,"registry store required" end
    local network=store.networks[networkId]; if not network then return nil,"unknown network" end
    if network.topologyDirty or network.topologyRevision~=network.revision then return nil,"topology pending" end
    budget=math.floor(tonumber(budget) or 0); if budget<1 then return nil,"positive work budget required" end
    local networkJobs=runtimeFor(store,jobs); local job=networkJobs[networkId]
    if not job or job.revision~=network.revision then job=start(store,networkId,network) end
    local work=0
    while work<budget do
        if job.phase=="discover" then
            local id=Iteration.nextEntry(network.nodes,job.cursor)
            if id then job.cursor=id; job.nodeIds[#job.nodeIds+1]=id; work=work+1
            else job.phase="inspect" end
        elseif job.index<=#job.nodeIds then
            local nodeId=job.nodeIds[job.index]; job.index=job.index+1; work=work+1
            local componentId=network.componentByNode[nodeId]
            local target=component(job.components,componentId)
            target.nodeCount=target.nodeCount+1
            local state=Infrastructure.inspectNode(store,nodeId,context)
            if state then addState(target,state) else target.unavailableCount=target.unavailableCount+1 end
        else
            if network.revision~=job.revision then networkJobs[networkId]=nil; return {complete=false,work=work,restarted=true} end
            for _,target in pairs(job.components) do finalize(target) end
            local report={schemaVersion=1,networkId=networkId,networkRevision=job.revision,
                componentCount=network.componentCount,components=job.components}
            runtimeFor(store,published)[networkId]=report; networkJobs[networkId]=nil
            return {complete=true,work=work,report=report}
        end
    end
    return {complete=false,work=work,phase=job.phase,networkRevision=job.revision,
        discovered=#job.nodeIds,inspected=job.index-1}
end

function Hydraulics.getReport(store,networkId)
    local report=runtimeFor(store,published)[networkId]
    local network=type(store)=="table" and type(store.networks)=="table" and store.networks[networkId] or nil
    if not report or not network or report.networkRevision~=network.revision then return nil,"hydraulic report pending" end
    return report
end

function Hydraulics.invalidate(store,networkId)
    runtimeFor(store,jobs)[networkId]=nil; runtimeFor(store,published)[networkId]=nil
end

waterWorks.Hydraulics=Hydraulics
waterWorks.stepHydraulics=Hydraulics.step
_G.waterWorks=waterWorks
return Hydraulics
