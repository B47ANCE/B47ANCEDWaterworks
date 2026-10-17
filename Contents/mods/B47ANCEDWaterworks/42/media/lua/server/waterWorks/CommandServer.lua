local waterWorks=rawget(_G,"waterWorks") or require "waterWorks/API"
local Network=waterWorks.Network or require "waterWorks/Network"
local Registry=waterWorks.Registry or require "waterWorks/Registry"
local Connections=waterWorks.Connections or require "waterWorks/Connections"
local Commands=require "waterWorks/Commands"
local Iteration=require "waterWorks/Iteration"
local DemandScheduler=require "waterWorks/DemandScheduler"
local Server={MAX_COMMANDS_PER_TICK=8,MAX_CACHED_REQUESTS=64,MAX_SUBSCRIPTIONS=16,
    SNAPSHOT_PAGE_SIZE=64,SUBSCRIBE_REACH=12,DELTA_RELEVANCE=50,TOPOLOGY_WORK_PER_TICK=16}
local allowance=setmetatable({},{__mode="k"})
local caches=setmetatable({},{__mode="k"})
local subscriptions=setmetatable({},{__mode="k"})
local topologyCursor=nil

local function validString(value,max)
    return type(value)=="string" and value~="" and #value<=max and not value:find("[%c]",1)
end
local function reply(player,command,payload)
    if type(sendServerCommand)~="function" then return false end
    return pcall(sendServerCommand,player,Commands.MODULE,command,payload)
end
local function coordinate(value,key)
    if type(value)=="table" and type(value[key])=="number" then return value[key] end
    local ok,fn=pcall(function() return value and value["get"..key:upper()] end)
    if not ok or type(fn)~="function" then return nil end
    local called,result=pcall(fn,value); return called and tonumber(result) or nil
end
local function closeEnough(player,node,radius)
    local px,py,pz=coordinate(player,"x"),coordinate(player,"y"),coordinate(player,"z")
    if not px or not py or not pz or type(node)~="table" then return false end
    local dx,dy,dz=px-(node.x or 0),py-(node.y or 0),(pz-(node.z or 0))*3
    return dx*dx+dy*dy+dz*dz<=radius*radius
end
local function subscriptionFor(player)
    local value=subscriptions[player]
    if not value then value={}; subscriptions[player]=value end
    return value
end
local function subscriptionCount(value)
    local count=0; for _ in pairs(value) do count=count+1 end; return count
end
local function snapshotPage(store,networkId,cursor,expectedRevision)
    local network=store.networks and store.networks[networkId]
    if not network then return nil,"unknown network" end
    if network.topologyDirty or network.topologyRevision~=network.revision then return nil,"topology pending" end
    if expectedRevision~=nil and tonumber(expectedRevision)~=network.revision then return nil,"snapshot revision changed" end
    if cursor~=nil and (not validString(cursor,Commands.MAX_NODE_ID) or not network.nodes[cursor]) then
        return nil,"invalid snapshot cursor"
    end
    local nodes,edges={},{}; local current=cursor; local nextCursor=nil
    for _=1,Server.SNAPSHOT_PAGE_SIZE do
        local id,node=Iteration.nextEntry(network.nodes,current)
        if not id then nextCursor=nil; break end
        current=id; nextCursor=id
        nodes[#nodes+1]={id=id,kind=node.kind,channel=node.channel,enabled=node.enabled~=false,
            x=node.x,y=node.y,z=node.z,componentId=network.componentByNode[id]}
        for neighbor in pairs(network.adjacency[id] or {}) do
            if id<neighbor then edges[#edges+1]={a=id,b=neighbor} end
        end
    end
    if Iteration.nextEntry(network.nodes,nextCursor)==nil then nextCursor=nil end
    return {schemaVersion=1,networkId=networkId,revision=network.revision,cursor=cursor,
        nextCursor=nextCursor,complete=nextCursor==nil,nodes=nodes,edges=edges,
        componentCount=network.componentCount}
end
local function subscribe(player,args)
    if not validString(args.networkId,Commands.MAX_NETWORK_ID)
        or not validString(args.anchorNodeId,Commands.MAX_NODE_ID) then return false,"invalid subscription request" end
    local store=Registry.getStore(); if not store then return false,"network registry unavailable" end
    local index=store.nodeIndex and store.nodeIndex[args.anchorNodeId]
    local network=index and store.networks[index.networkId]
    local node=network and network.nodes[args.anchorNodeId]
    if not index or index.networkId~=args.networkId or not node then return false,"anchor node unavailable" end
    if not Registry.getRuntimeObject(store,args.anchorNodeId) then return false,"anchor node not loaded" end
    if not closeEnough(player,node,Server.SUBSCRIBE_REACH) then return false,"anchor node out of reach" end
    local owned=subscriptionFor(player)
    if not owned[args.networkId] and subscriptionCount(owned)>=Server.MAX_SUBSCRIPTIONS then return false,"subscription limit reached" end
    owned[args.networkId]=true
    local page,err=snapshotPage(store,args.networkId,args.cursor,args.revision)
    if not page then return false,err end
    reply(player,Commands.SNAPSHOT,page)
    return true,page
end
local function publishDelta(store,payload)
    local network=store.networks and store.networks[payload.networkId]
    local a=network and network.nodes[payload.nodeA]; local b=network and network.nodes[payload.nodeB]
    for player,owned in pairs(subscriptions) do
        if owned[payload.networkId] then
            if (a and closeEnough(player,a,Server.DELTA_RELEVANCE)) or (b and closeEnough(player,b,Server.DELTA_RELEVANCE)) then
                reply(player,Commands.DELTA,payload)
            else owned[payload.networkId]=nil end
        end
    end
end
local function cacheFor(player)
    local value=caches[player]
    if not value then value={map={},order={}}; caches[player]=value end
    return value
end
local function remember(player,requestId,result)
    local cache=cacheFor(player)
    cache.map[requestId]=result; cache.order[#cache.order+1]=requestId
    while #cache.order>Server.MAX_CACHED_REQUESTS do
        local expired=table.remove(cache.order,1); cache.map[expired]=nil
    end
end
local function resultPayload(requestId,ok,value)
    local reason,proposal
    if ok then proposal=value else reason=tostring(value or "request failed")end
    return {schemaVersion=1,requestId=requestId,ok=ok==true,reason=reason,proposal=proposal}
end
local function listEach(list,callback,limit)
    limit=limit or 128
    if type(list)=="table" then
        local count=0; for _,value in pairs(list) do count=count+1; if count>limit then break end; callback(value) end
        return
    end
    local okSize,size=pcall(function() return list and list:size() end)
    if not okSize then return end
    for index=0,math.min(tonumber(size) or 0,limit)-1 do
        local ok,value=pcall(function() return list:get(index) end); if ok then callback(value) end
    end
end
local function method(object,name,...)
    local ok,fn=pcall(function() return object and object[name] end)
    if not ok or type(fn)~="function" then return nil end
    local called,value=pcall(fn,object,...); return called and value or nil
end
local function claimPlacedDevice(player,args,store,expectedType,label,attacher)
    local x,y,z=tonumber(args.x),tonumber(args.y),tonumber(args.z)
    if not x or not y or not z or x~=x or y~=y or z~=z then return false,"invalid placement coordinates" end
    x,y,z=math.floor(x),math.floor(y),math.floor(z)
    if not closeEnough(player,{x=x,y=y,z=z},Connections.DEFAULT_ACTOR_REACH) then return false,"placed "..label.." out of reach" end
    if not validString(args.itemId,Commands.MAX_ITEM_ID) then return false,"valid item id required" end
    local cell=type(getCell)=="function" and getCell() or nil
    local square=method(cell,"getGridSquare",x,y,z); if not square then return false,"placement square unavailable" end
    local found=nil
    listEach(method(square,"getWorldObjects"),function(object)
        if found then return end
        local item=method(object,"getItem")
        if item and tostring(method(item,"getID"))==args.itemId
            and method(item,"getFullType")==expectedType then found=object end
    end)
    if not found then return false,"placed "..label.." not found" end
    local ok,value
    if type(attacher)=="function"then ok,value=attacher(store,found)
    else ok,value=Registry.attachObject(store,found)end
    if not ok then return false,value end
    return true,{nodeId=value.nodeId,networkId=value.networkId,created=value.created==true,x=x,y=y,z=z}
end
local function claimPlacedPump(player,args,store)
    return claimPlacedDevice(player,args,store,"waterWorks.PortableTransferPump","pump")
end
local function claimPlacedTreatment(player,args,store)
    return claimPlacedDevice(player,args,store,"waterWorks.ElectricWaterPurifier","treatment device")
end
local function claimPlacedValve(player,args,store)
    local Valves=waterWorks.FirstPartyValves or require "waterWorks/FirstPartyValves"
    return claimPlacedDevice(player,args,store,Valves.INLINE_TYPE,"valve",function(activeStore,object)
        return Valves.claim(activeStore,object,"WATER")
    end)
end
local function claimVanillaFixture(player,args,store)
    local x,y,z=tonumber(args.x),tonumber(args.y),tonumber(args.z);local index=tonumber(args.objectIndex)
    if not x or not y or not z or x~=x or y~=y or z~=z or not index or index~=math.floor(index)
        or index<0 or index>2048 or not validString(args.spriteName,128)then return false,"invalid fixture identity"end
    x,y,z=math.floor(x),math.floor(y),math.floor(z)
    if not closeEnough(player,{x=x,y=y,z=z},Connections.DEFAULT_ACTOR_REACH)then return false,"fixture out of reach"end
    local cell=type(getCell)=="function"and getCell()or nil;local square=method(cell,"getGridSquare",x,y,z)
    if not square then return false,"fixture square unavailable"end
    local found=nil
    listEach(method(square,"getObjects"),function(object)
        if not found and tonumber(method(object,"getObjectIndex"))==index
            and method(object,"getSpriteName")==args.spriteName and method(object,"getFluidContainer")then found=object end
    end)
    if not found then return false,"fixture not found"end
    local Vanilla=waterWorks.VanillaProviders or require "waterWorks/VanillaProviders"
    local ok,value=Vanilla.claimObject(store,found,"WATER");if not ok then return false,value end
    return true,{nodeId=value.nodeId,networkId=value.networkId,created=value.created==true,x=x,y=y,z=z}
end
local worldHour
local function transferFlow(player,args,store)
    local Flow=waterWorks.Flow or require "waterWorks/Flow"
    if not validString(args.sourceId,Commands.MAX_NODE_ID) or not validString(args.targetId,Commands.MAX_NODE_ID) then
        return false,"valid flow endpoints required"
    end
    local amount=tonumber(args.amount)
    if not amount or amount~=amount or amount<=0 or amount>Commands.MAX_FLOW_AMOUNT then return false,"invalid flow amount" end
    local function node(id)
        local index=store.nodeIndex and store.nodeIndex[id]; local network=index and store.networks[index.networkId]
        return network and network.nodes and network.nodes[id] or nil
    end
    local source,target=node(args.sourceId),node(args.targetId)
    if not source or not target then return false,"flow endpoint unavailable" end
    if not closeEnough(player,source,Connections.DEFAULT_ACTOR_REACH)
        or not closeEnough(player,target,Connections.DEFAULT_ACTOR_REACH) then return false,"flow endpoint out of reach" end
    return Flow.transfer(store,args.sourceId,args.targetId,amount,
        {operationId="waterWorks.command:"..args.requestId,minimumPressure=tonumber(args.minimumPressure) or 0})
end
local function treatNetwork(player,args,store)
    if not validString(args.deviceId,Commands.MAX_NODE_ID)or not validString(args.targetId,Commands.MAX_NODE_ID)
        or args.deviceId==args.targetId or not validString(args.treatmentId,64)then
        return false,"valid treatment request required"
    end
    local function node(id)
        local index=store.nodeIndex and store.nodeIndex[id];local network=index and store.networks[index.networkId]
        return network and network.nodes and network.nodes[id]or nil
    end
    local device,target=node(args.deviceId),node(args.targetId)
    if not device or not target then return false,"treatment endpoint unavailable"end
    if not closeEnough(player,device,Connections.DEFAULT_ACTOR_REACH)
        or not closeEnough(player,target,Connections.DEFAULT_ACTOR_REACH)then return false,"treatment endpoint out of reach"end
    local Devices=waterWorks.TreatmentDevices or require "waterWorks/TreatmentDevices"
    return Devices.treat(store,args.deviceId,args.targetId,{treatmentId=args.treatmentId,
        operationId="waterWorks.command:"..args.requestId,worldAgeHours=worldHour()})
end
local function heatNetwork(player,args,store)
    if not validString(args.deviceId,Commands.MAX_NODE_ID)or not validString(args.targetId,Commands.MAX_NODE_ID)
        or args.deviceId==args.targetId then return false,"valid heating request required"end
    local delta=tonumber(args.deltaC)
    if not delta or delta~=delta or delta<=0 or delta>20 or delta==math.huge then return false,"invalid heat delta"end
    local function node(id)
        local index=store.nodeIndex and store.nodeIndex[id];local network=index and store.networks[index.networkId]
        return network and network.nodes and network.nodes[id]or nil
    end
    local device,target=node(args.deviceId),node(args.targetId)
    if not device or not target then return false,"heating endpoint unavailable"end
    if not closeEnough(player,device,Connections.DEFAULT_ACTOR_REACH)
        or not closeEnough(player,target,Connections.DEFAULT_ACTOR_REACH)then return false,"heating endpoint out of reach"end
    local Devices=waterWorks.TreatmentDevices or require "waterWorks/TreatmentDevices"
    return Devices.heat(store,args.deviceId,args.targetId,{deltaC=delta,
        operationId="waterWorks.command:"..args.requestId})
end
local function repairNetwork(player,args,store)
    if not validString(args.nodeId,Commands.MAX_NODE_ID)or not validString(args.kitId,Commands.MAX_ITEM_ID)then
        return false,"valid repair request required"
    end
    local index=store.nodeIndex and store.nodeIndex[args.nodeId];local network=index and store.networks[index.networkId]
    local node=network and network.nodes and network.nodes[args.nodeId]
    if not node then return false,"repair node unavailable"end
    if not Registry.getRuntimeObject(store,args.nodeId)then return false,"repair node not loaded"end
    if not closeEnough(player,node,Connections.DEFAULT_ACTOR_REACH)then return false,"repair node out of reach"end
    local Maintenance=waterWorks.Maintenance or require "waterWorks/Maintenance"
    return Maintenance.repair(store,args.nodeId,player,args.kitId,"waterWorks.command:"..args.requestId)
end
local function setValve(player,args,store)
    if not validString(args.nodeId,Commands.MAX_NODE_ID)or type(args.open)~="boolean"then
        return false,"valid valve request required"
    end
    local index=store.nodeIndex and store.nodeIndex[args.nodeId];local network=index and store.networks[index.networkId]
    local node=network and network.nodes and network.nodes[args.nodeId]
    if not node or node.kind~="valve"then return false,"valve node unavailable"end
    if not Registry.getRuntimeObject(store,args.nodeId)then return false,"valve node not loaded"end
    if not closeEnough(player,node,Connections.DEFAULT_ACTOR_REACH)then return false,"valve out of reach"end
    return waterWorks.requestInfrastructureAction(store,args.nodeId,"set-open",{open=args.open},
        {player=player,operationId="waterWorks.command:"..args.requestId})
end
worldHour=function()
    local gameTime=type(getGameTime)=="function"and getGameTime()or nil
    local value=method(gameTime,"getWorldAgeHours")
    value=tonumber(value);if value and value==value and value>=0 and value~=math.huge then return value end
    return nil
end
local function demandEndpoints(player,args,store)
    if not validString(args.sourceId,Commands.MAX_NODE_ID)or not validString(args.targetId,Commands.MAX_NODE_ID)
        or args.sourceId==args.targetId then return nil,"valid distinct demand endpoints required"end
    local function resolve(id)
        local index=store.nodeIndex and store.nodeIndex[id];local network=index and store.networks[index.networkId]
        return network and network.nodes and network.nodes[id]or nil
    end
    local source,target=resolve(args.sourceId),resolve(args.targetId)
    if not source or not target then return nil,"demand endpoint unavailable"end
    if not closeEnough(player,source,Connections.DEFAULT_ACTOR_REACH)
        or not closeEnough(player,target,Connections.DEFAULT_ACTOR_REACH)then return nil,"demand endpoint out of reach"end
    return {source=source,target=target}
end
local function existingDemand(store,sourceId,targetId)
    local report=DemandScheduler.inspect(store);if not report then return nil end
    local cursor=nil
    for _=1,DemandScheduler.MAX_SCHEDULES do
        local id,entry=Iteration.nextEntry(report.entries,cursor);if not id then return nil end
        cursor=id;if entry.sourceId==sourceId and entry.targetId==targetId then return entry end
    end
    return nil
end
local function configureDemand(player,args,store)
    local endpoints,endpointErr=demandEndpoints(player,args,store);if not endpoints then return false,endpointErr end
    local amount,interval=tonumber(args.amount),tonumber(args.intervalHours)
    if not amount or amount~=amount or amount<=0 or amount>Commands.MAX_FLOW_AMOUNT or amount==math.huge
        or not interval or interval~=interval or interval<Commands.MIN_DEMAND_INTERVAL
        or interval>Commands.MAX_DEMAND_INTERVAL or interval==math.huge then return false,"invalid demand amount or interval"end
    local Flow=waterWorks.Flow or require "waterWorks/Flow"
    local preview,previewErr=Flow.preview(store,args.sourceId,args.targetId,amount,{minimumPressure=0})
    if not preview then return false,previewErr end
    local current=existingDemand(store,args.sourceId,args.targetId)
    local now=worldHour();if not now then return false,"world time unavailable"end
    local id=current and current.id or("demand:"..args.requestId)
    local ok,value=DemandScheduler.schedule(store,{id=id,sourceId=args.sourceId,targetId=args.targetId,
        amount=amount,intervalHours=interval,nextRunHour=now+interval,minimumPressure=0,enabled=true})
    if not ok then return false,value end
    return true,{id=value.id,sourceId=value.sourceId,targetId=value.targetId,amount=value.amount,
        intervalHours=value.intervalHours,nextRunHour=value.nextRunHour,updated=current~=nil}
end
local function cancelDemand(player,args,store)
    local endpoints,endpointErr=demandEndpoints(player,args,store);if not endpoints then return false,endpointErr end
    local current=existingDemand(store,args.sourceId,args.targetId)
    if not current then return false,"scheduled demand not found"end
    local ok,value=DemandScheduler.cancel(store,current.id);if not ok then return false,value end
    return true,{id=current.id,sourceId=current.sourceId,targetId=current.targetId,cancelled=true}
end

local function cachedMutation(player,args,operation)
    if not player or type(args)~="table"or not validString(args.requestId,Commands.MAX_REQUEST_ID)then
        return false,"invalid request"
    end
    local cache=cacheFor(player);local prior=cache.map[args.requestId]
    if prior then reply(player,Commands.RESULT,prior);return prior.ok,prior end
    local remaining=allowance[player];if remaining==nil then remaining=Server.MAX_COMMANDS_PER_TICK end
    if remaining<=0 then
        local limited=resultPayload(args.requestId,false,"rate limited")
        remember(player,args.requestId,limited);reply(player,Commands.RESULT,limited);return false,limited
    end
    allowance[player]=remaining-1
    local store=Registry.getStore();local ok,value=false,"network registry unavailable"
    if store then ok,value=operation(player,args,store)end
    local result=resultPayload(args.requestId,ok,value)
    remember(player,args.requestId,result);reply(player,Commands.RESULT,result)
    return ok,result
end

function Server.handle(module,command,player,args)
    if module~=Commands.MODULE then return nil,"unhandled module" end
    if command==Commands.SUBSCRIBE then
        if not player or type(args)~="table" then return false,"invalid request" end
        local remaining=allowance[player]
        if remaining==nil then remaining=Server.MAX_COMMANDS_PER_TICK end
        if remaining<=0 then
            reply(player,Commands.SNAPSHOT_ERROR,{networkId=tostring(args.networkId or""):sub(1,Commands.MAX_NETWORK_ID),reason="rate limited"})
            return false,"rate limited"
        end
        allowance[player]=remaining-1
        local ok,value=subscribe(player,args)
        if not ok then reply(player,Commands.SNAPSHOT_ERROR,{networkId=tostring(args.networkId or""):sub(1,Commands.MAX_NETWORK_ID),reason=tostring(value or"snapshot rejected"):sub(1,160)})end
        return ok,value
    end
    if command==Commands.CLAIM_PUMP then
        if not player or type(args)~="table" or not validString(args.requestId,Commands.MAX_REQUEST_ID) then
            return false,"invalid request"
        end
        local cache=cacheFor(player); local prior=cache.map[args.requestId]
        if prior then reply(player,Commands.RESULT,prior); return prior.ok,prior end
        local remaining=allowance[player]; if remaining==nil then remaining=Server.MAX_COMMANDS_PER_TICK end
        if remaining<=0 then
            local limited=resultPayload(args.requestId,false,"rate limited")
            remember(player,args.requestId,limited); reply(player,Commands.RESULT,limited); return false,limited
        end
        allowance[player]=remaining-1
        local store=Registry.getStore(); local ok,value=false,"network registry unavailable"
        if store then ok,value=claimPlacedPump(player,args,store) end
        local result=resultPayload(args.requestId,ok,value)
        remember(player,args.requestId,result); reply(player,Commands.RESULT,result)
        return ok,result
    end
    if command==Commands.CLAIM_TREATMENT then return cachedMutation(player,args,claimPlacedTreatment)end
    if command==Commands.CLAIM_VALVE then return cachedMutation(player,args,claimPlacedValve)end
    if command==Commands.CLAIM_FIXTURE then return cachedMutation(player,args,claimVanillaFixture)end
    if command==Commands.FLOW then
        if not player or type(args)~="table" or not validString(args.requestId,Commands.MAX_REQUEST_ID) then
            return false,"invalid request"
        end
        local cache=cacheFor(player); local prior=cache.map[args.requestId]
        if prior then reply(player,Commands.RESULT,prior); return prior.ok,prior end
        local remaining=allowance[player]; if remaining==nil then remaining=Server.MAX_COMMANDS_PER_TICK end
        if remaining<=0 then
            local limited=resultPayload(args.requestId,false,"rate limited")
            remember(player,args.requestId,limited); reply(player,Commands.RESULT,limited); return false,limited
        end
        allowance[player]=remaining-1
        local store=Registry.getStore(); local ok,value=false,"network registry unavailable"
        if store then ok,value=transferFlow(player,args,store) end
        local result=resultPayload(args.requestId,ok,value)
        remember(player,args.requestId,result); reply(player,Commands.RESULT,result)
        return ok,result
    end
    if command==Commands.TREAT then return cachedMutation(player,args,treatNetwork)end
    if command==Commands.HEAT then return cachedMutation(player,args,heatNetwork)end
    if command==Commands.REPAIR then return cachedMutation(player,args,repairNetwork)end
    if command==Commands.SET_VALVE then return cachedMutation(player,args,setValve)end
    if command==Commands.SCHEDULE_DEMAND then return cachedMutation(player,args,configureDemand)end
    if command==Commands.CANCEL_DEMAND then return cachedMutation(player,args,cancelDemand)end
    local operation=command==Commands.CONNECT and "connect" or command==Commands.DISCONNECT and "disconnect" or nil
    if not operation then return nil,"unhandled command" end
    if not player or type(args)~="table" or not validString(args.requestId,Commands.MAX_REQUEST_ID)
        or not validString(args.nodeA,Commands.MAX_NODE_ID) or not validString(args.nodeB,Commands.MAX_NODE_ID) then
        return false,"invalid request"
    end
    local cache=cacheFor(player); local prior=cache.map[args.requestId]
    if prior then reply(player,Commands.RESULT,prior); return prior.ok,prior end
    local remaining=allowance[player]
    if remaining==nil then remaining=Server.MAX_COMMANDS_PER_TICK end
    if remaining<=0 then
        local limited=resultPayload(args.requestId,false,"rate limited")
        remember(player,args.requestId,limited); reply(player,Commands.RESULT,limited); return false,limited
    end
    allowance[player]=remaining-1
    local store=Registry.getStore()
    if not store then
        local unavailable=resultPayload(args.requestId,false,"network registry unavailable")
        remember(player,args.requestId,unavailable); reply(player,Commands.RESULT,unavailable); return false,unavailable
    end
    local ok,value=Connections.request(store,operation,args.nodeA,args.nodeB,
        {actor=player,commandArgs=args,maxNodeDistance=Connections.DEFAULT_NODE_DISTANCE,
            maxActorReach=Connections.DEFAULT_ACTOR_REACH})
    local result=resultPayload(args.requestId,ok,value)
    remember(player,args.requestId,result); reply(player,Commands.RESULT,result)
    if ok then
        publishDelta(store,{schemaVersion=1,operation=operation,nodeA=args.nodeA,nodeB=args.nodeB,
            networkId=value.networkId,revision=value.revision,requestId=args.requestId})
    end
    return ok,result
end

function Server.refill() allowance=setmetatable({},{__mode="k"}) end
function Server.maintainTopology()
    local store=Registry.getStore(); if not store or type(store.networks)~="table" then return false end
    local id,network=Iteration.nextEntry(store.networks,topologyCursor)
    if not id then topologyCursor=nil;id,network=Iteration.nextEntry(store.networks,nil)end
    if not id then return false end
    topologyCursor=id
    if network.topologyDirty then Network.stepTopology(network,Server.TOPOLOGY_WORK_PER_TICK) end
    return true,id
end
local function onTick() Server.refill(); Server.maintainTopology() end
local function onCommand(module,command,player,args)
    local ok,err=pcall(Server.handle,module,command,player,args)
    if not ok and print then print("[B47ANCEDWaterworks] Connection command failed safely: "..tostring(err)) end
end
if Events and Events.OnClientCommand then Events.OnClientCommand.Add(onCommand) end
if Events and Events.OnTick then Events.OnTick.Add(onTick) end
waterWorks.CommandServer=Server
Server.Subscriptions=subscriptions
return Server
