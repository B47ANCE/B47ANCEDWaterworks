local waterWorks=rawget(_G,"waterWorks") or require "waterWorks/API"
local Registry=waterWorks.Registry or require "waterWorks/Registry"
local Infrastructure=waterWorks.Infrastructure or require "waterWorks/Infrastructure"
local Hydraulics=waterWorks.Hydraulics or require "waterWorks/Hydraulics"
local Flow={MAX_PATH_NODES=256}
local locks={}
local operationCounter=0

local function authoritative()
    return not (type(isClient)=="function" and isClient()==true)
end
local function edgeId(a,b) if a>b then a,b=b,a end; return a.."\0"..b end
local function resolve(store,nodeId)
    local index=type(store)=="table" and type(store.nodeIndex)=="table" and store.nodeIndex[nodeId] or nil
    local network=index and store.networks and store.networks[index.networkId]
    local node=network and network.nodes and network.nodes[nodeId]
    local object=node and Registry.getRuntimeObject(store,nodeId) or nil
    if not index or not network or not node then return nil,"unknown node" end
    if not object then return nil,"node not loaded" end
    local state,stateErr=Infrastructure.inspectNode(store,nodeId)
    if not state then return nil,stateErr end
    return {index=index,network=network,node=node,object=object,state=state}
end
local function traversable(store,nodeId,cache,allowFrozenNodeId,allowBatchSourceId)
    local value=cache[nodeId]
    if value~=nil then return value end
    local state=Infrastructure.inspectNode(store,nodeId)
    local thermal=waterWorks.Thermal
    value=state~=nil and (nodeId==allowFrozenNodeId or not(thermal and thermal.isFrozen(store,nodeId)))
        and state.available~=false and state.enabled~=false
        and not (state.kind=="valve" and state.open==false)
        and not (state.kind=="filter" and state.batchFilter==true and nodeId~=allowBatchSourceId)
        and not (state.kind=="pump" and state.powered~=true)
    cache[nodeId]=value
    return value
end
local function findPath(store,network,startId,targetId,allowFrozenNodeId,allowBatchSourceId)
    local queue={startId}; local head=1; local previous={[startId]=false}; local inspected=0; local cache={}
    while head<=#queue and inspected<Flow.MAX_PATH_NODES do
        local id=queue[head]; head=head+1; inspected=inspected+1
        if id==targetId then
            local path={}; local cursor=id
            while cursor do table.insert(path,1,cursor); cursor=previous[cursor] end
            return path,inspected
        end
        if traversable(store,id,cache,allowFrozenNodeId,allowBatchSourceId) then
            for neighbor in pairs(network.adjacency[id] or {}) do
                if previous[neighbor]==nil and traversable(store,neighbor,cache,allowFrozenNodeId,allowBatchSourceId) then
                    previous[neighbor]=id; queue[#queue+1]=neighbor
                end
            end
        end
    end
    return nil,inspected,head<=#queue and "path search budget exceeded" or "no open loaded path"
end

function Flow.findOpenPath(store,startId,targetId,options)
    options=type(options)=="table"and options or{}
    local source,sourceErr=resolve(store,startId); if not source then return nil,sourceErr end
    local target,targetErr=resolve(store,targetId); if not target then return nil,targetErr end
    if source.network~=target.network or source.index.networkId~=target.index.networkId then return nil,"nodes belong to different networks" end
    if source.node.channel~=target.node.channel then return nil,"channel mismatch" end
    local allowed=options.allowFrozenTarget==true and targetId or nil
    local path,inspected,err=findPath(store,source.network,startId,targetId,allowed,options.allowBatchFilterSource==true and startId or nil)
    if not path then return nil,err end
    return {path=path,pathNodesInspected=inspected,networkId=source.index.networkId,source=source,target=target}
end

function Flow.preview(store,sourceId,targetId,amount,options)
    options=type(options)=="table" and options or {}
    if sourceId==targetId then return nil,"source and target must differ" end
    local source,sourceErr=resolve(store,sourceId); if not source then return nil,sourceErr end
    local target,targetErr=resolve(store,targetId); if not target then return nil,targetErr end
    if source.index.networkId~=target.index.networkId or source.network~=target.network then return nil,"nodes belong to different networks" end
    if source.node.channel~=target.node.channel then return nil,"channel mismatch" end
    if source.state.kind~="source" and source.state.kind~="storage" then return nil,"invalid source role" end
    if target.state.kind~="storage" and target.state.kind~="fixture" and target.state.kind~="treatment" then
        return nil,"invalid target role"
    end
    local requested=tonumber(amount)
    if not requested or requested~=requested or requested<=0 or requested==math.huge then return nil,"invalid flow amount" end
    local route,pathErr=Flow.findOpenPath(store,sourceId,targetId); if not route then return nil,pathErr end
    local path,inspected=route.path,route.pathNodesInspected
    local report=Hydraulics.getReport(store,source.index.networkId)
    local componentId=source.network.componentByNode[sourceId]
    local hydraulic=report and report.components and report.components[componentId] or nil
    local minimum=math.max(0,tonumber(options.minimumPressure) or 0)
    if minimum>0 and (not hydraulic or not hydraulic.reliable or not hydraulic.estimatedPressure
        or hydraulic.estimatedPressure<minimum) then return nil,"insufficient verified pressure" end
    return {sourceId=sourceId,targetId=targetId,networkId=source.index.networkId,amount=requested,
        path=path,pathNodesInspected=inspected,minimumPressure=minimum,source=source,target=target}
end

local function rollbackReservations(power,reservations)
    local all=true
    for index=#reservations,1,-1 do
        local entry=reservations[index]
        local ok=type(power.rollbackEnergyTransaction)=="function"
            and power.rollbackEnergyTransaction(entry.consumer,entry.operationId)
        if not ok then all=false end
    end
    return all
end

function Flow.transfer(store,sourceId,targetId,amount,options)
    if not authoritative() then return false,"non-authority" end
    local proposal,err=Flow.preview(store,sourceId,targetId,amount,options); if not proposal then return false,err end
    local id=edgeId(sourceId,targetId); if locks[id] then return false,"flow route busy" end
    locks[id]=true
    operationCounter=operationCounter+1
    local baseOperation=(options and options.operationId) or ("waterWorks.flow:"..tostring(operationCounter))
    local power=(rawget(_G,"B47ANCEDPower") or rawget(_G,"powerWorks")); local pumpPower=waterWorks.PumpPower
    local reservations={}
    for _,nodeId in ipairs(proposal.path) do
        local state=Infrastructure.inspectNode(store,nodeId)
        local energy=state and state.kind=="pump" and math.max(0,tonumber(state.energyPerFluidUnit) or 0)*proposal.amount or 0
        if energy>0 then
            if not power or type(power.beginEnergyTransaction)~="function" or not pumpPower then
                rollbackReservations(power or {},reservations); locks[id]=nil; return false,"pump energy transaction unavailable"
            end
            local consumer,consumerErr=pumpPower.getConsumer(store,nodeId)
            if not consumer then rollbackReservations(power,reservations); locks[id]=nil; return false,consumerErr end
            local operationId=baseOperation..":"..nodeId
            local reserved,reserveErr=power.beginEnergyTransaction(consumer,energy,operationId)
            if not reserved then rollbackReservations(power,reservations); locks[id]=nil; return false,reserveErr end
            reservations[#reservations+1]={consumer=consumer,operationId=operationId}
        end
    end
    local ok,result=waterWorks.transfer(proposal.source.object,proposal.target.object,proposal.amount,
        {operationId=baseOperation})
    if not ok then
        local restored=rollbackReservations(power or {},reservations); locks[id]=nil
        return false,tostring(result)..(restored and "; energy rollback verified" or "; energy recovery inspection required")
    end
    for _,entry in ipairs(reservations) do
        local committed=power.commitEnergyTransaction(entry.consumer,entry.operationId)
        if not committed then locks[id]=nil; return false,"fluid committed; pump energy recovery inspection required" end
    end
    locks[id]=nil
    Hydraulics.invalidate(store,proposal.networkId)
    return true,{networkId=proposal.networkId,sourceId=sourceId,targetId=targetId,
        amount=result.amount,quality=result.quality,state=result.state,pathLength=#proposal.path,
        operationId=result.operationId}
end

waterWorks.Flow=Flow
waterWorks.requestNetworkTransfer=Flow.transfer
_G.waterWorks=waterWorks
return Flow
