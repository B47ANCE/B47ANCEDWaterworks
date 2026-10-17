local waterWorks=rawget(_G,"waterWorks") or require "waterWorks/API"
local Commands=require "waterWorks/Commands"
local Client={Results={},Deltas={},Snapshots={},PendingSnapshots={},MAX_HISTORY=64,MAX_SNAPSHOT_PAGES=1024}
Client.PendingSediment={};Client.SedimentResults={}
local counter=0
local function append(list,value)
    list[#list+1]=value; while #list>Client.MAX_HISTORY do table.remove(list,1) end
end
local function nextId()
    counter=counter+1
    return "waterWorks:"..tostring(counter)
end
function Client.request(player,operation,nodeA,nodeB)
    if type(sendClientCommand)~="function" then return false,"sendClientCommand unavailable" end
    local command=operation=="connect" and Commands.CONNECT or operation=="disconnect" and Commands.DISCONNECT or nil
    if not command then return false,"unsupported operation" end
    local payload={requestId=nextId(),nodeA=nodeA,nodeB=nodeB}
    local ok,err=pcall(sendClientCommand,player,Commands.MODULE,command,payload)
    if not ok then return false,err end
    return true,payload.requestId
end
function Client.subscribe(player,networkId,anchorNodeId,cursor,revision)
    if type(sendClientCommand)~="function" then return false,"sendClientCommand unavailable" end
    local ok,err=pcall(sendClientCommand,player,Commands.MODULE,Commands.SUBSCRIBE,
        {networkId=networkId,anchorNodeId=anchorNodeId,cursor=cursor,revision=revision})
    return ok,err
end
function Client.requestSnapshot(player,networkId,anchorNodeId,callback)
    if not player or type(networkId)~="string"or networkId==""or type(anchorNodeId)~="string"or anchorNodeId==""then
        return false,"player, network, and anchor required"
    end
    Client.Snapshots[networkId]=nil
    Client.PendingSnapshots[networkId]={player=player,anchorNodeId=anchorNodeId,callback=callback,pages=0}
    local ok,err=Client.subscribe(player,networkId,anchorNodeId,nil,nil)
    if not ok then Client.PendingSnapshots[networkId]=nil;return false,err end
    return true
end
local function completePending(networkId,snapshot,reason)
    local pending=Client.PendingSnapshots[networkId];Client.PendingSnapshots[networkId]=nil
    if pending and type(pending.callback)=="function"then pcall(pending.callback,snapshot,reason)end
end
function Client.pumpSnapshots()
    for networkId,pending in pairs(Client.PendingSnapshots)do
        if pending.needsContinue then
            pending.needsContinue=false
            local ok,err=Client.subscribe(pending.player,networkId,pending.anchorNodeId,pending.cursor,pending.revision)
            if not ok then completePending(networkId,nil,err)end
            return ok
        end
    end
    return false
end
function Client.claimPlacedPump(player,worldObject)
    if type(sendClientCommand)~="function" then return false,"sendClientCommand unavailable" end
    local function call(object,name)
        local ok,value=pcall(function() return object[name](object) end); return ok and value or nil
    end
    local item=call(worldObject,"getItem")
    local id=item and call(item,"getID")
    local x,y,z=call(worldObject,"getX"),call(worldObject,"getY"),call(worldObject,"getZ")
    if id==nil or x==nil or y==nil or z==nil then return false,"placed pump identity unavailable" end
    local payload={requestId=nextId(),itemId=tostring(id),x=x,y=y,z=z}
    local ok,err=pcall(sendClientCommand,player,Commands.MODULE,Commands.CLAIM_PUMP,payload)
    if not ok then return false,err end
    return true,payload.requestId
end
function Client.claimPlacedTreatment(player,worldObject)
    if type(sendClientCommand)~="function" then return false,"sendClientCommand unavailable" end
    local function call(object,name)
        local ok,value=pcall(function() return object[name](object) end); return ok and value or nil
    end
    local item=call(worldObject,"getItem");local id=item and call(item,"getID")
    local x,y,z=call(worldObject,"getX"),call(worldObject,"getY"),call(worldObject,"getZ")
    if id==nil or x==nil or y==nil or z==nil then return false,"placed treatment identity unavailable"end
    local payload={requestId=nextId(),itemId=tostring(id),x=x,y=y,z=z}
    local ok,err=pcall(sendClientCommand,player,Commands.MODULE,Commands.CLAIM_TREATMENT,payload)
    if not ok then return false,err end
    return true,payload.requestId
end
function Client.claimPlacedValve(player,worldObject)
    if type(sendClientCommand)~="function"then return false,"sendClientCommand unavailable"end
    local function call(object,name)
        local ok,value=pcall(function()return object[name](object)end);return ok and value or nil
    end
    local item=call(worldObject,"getItem");local id=item and call(item,"getID")
    local x,y,z=call(worldObject,"getX"),call(worldObject,"getY"),call(worldObject,"getZ")
    if id==nil or x==nil or y==nil or z==nil then return false,"placed valve identity unavailable"end
    local payload={requestId=nextId(),itemId=tostring(id),x=x,y=y,z=z}
    local ok,err=pcall(sendClientCommand,player,Commands.MODULE,Commands.CLAIM_VALVE,payload)
    if not ok then return false,err end
    return true,payload.requestId
end
function Client.claimVanillaFixture(player,object)
    if type(sendClientCommand)~="function"then return false,"sendClientCommand unavailable"end
    local function call(target,name)
        local ok,value=pcall(function()return target[name](target)end);return ok and value or nil
    end
    local x,y,z=call(object,"getX"),call(object,"getY"),call(object,"getZ")
    local index,sprite=call(object,"getObjectIndex"),call(object,"getSpriteName")
    if x==nil or y==nil or z==nil or index==nil or type(sprite)~="string"or sprite==""then
        return false,"fixture identity unavailable"
    end
    local payload={requestId=nextId(),x=x,y=y,z=z,objectIndex=index,spriteName=sprite}
    local ok,err=pcall(sendClientCommand,player,Commands.MODULE,Commands.CLAIM_FIXTURE,payload)
    if not ok then return false,err end
    return true,payload.requestId
end
function Client.setValveOpen(player,nodeId,open)
    if type(sendClientCommand)~="function"then return false,"sendClientCommand unavailable"end
    if not player or type(nodeId)~="string"or nodeId==""or type(open)~="boolean"then
        return false,"valid valve request required"
    end
    local payload={requestId=nextId(),nodeId=nodeId,open=open}
    local ok,err=pcall(sendClientCommand,player,Commands.MODULE,Commands.SET_VALVE,payload)
    if not ok then return false,err end
    return true,payload.requestId
end
function Client.requestTreatment(player,deviceId,targetId,treatmentId)
    if type(sendClientCommand)~="function"then return false,"sendClientCommand unavailable"end
    if not player or type(deviceId)~="string"or type(targetId)~="string"or deviceId==targetId then
        return false,"valid treatment endpoints required"
    end
    local payload={requestId=nextId(),deviceId=deviceId,targetId=targetId,treatmentId=treatmentId or"boiled"}
    local ok,err=pcall(sendClientCommand,player,Commands.MODULE,Commands.TREAT,payload)
    if not ok then return false,err end
    return true,payload.requestId
end
function Client.requestHeat(player,deviceId,targetId,deltaC)
    if type(sendClientCommand)~="function"then return false,"sendClientCommand unavailable"end
    local delta=tonumber(deltaC)
    if not player or type(deviceId)~="string"or type(targetId)~="string"or deviceId==targetId
        or not delta or delta~=delta or delta<=0 or delta>20 then return false,"valid heating request required"end
    local payload={requestId=nextId(),deviceId=deviceId,targetId=targetId,deltaC=delta}
    local ok,err=pcall(sendClientCommand,player,Commands.MODULE,Commands.HEAT,payload)
    if not ok then return false,err end
    return true,payload.requestId
end
function Client.requestRepair(player,nodeId,kitId)
    if type(sendClientCommand)~="function"then return false,"sendClientCommand unavailable"end
    if not player or type(nodeId)~="string"or nodeId==""or kitId==nil then return false,"valid repair request required"end
    local payload={requestId=nextId(),nodeId=nodeId,kitId=tostring(kitId)}
    local ok,err=pcall(sendClientCommand,player,Commands.MODULE,Commands.REPAIR,payload)
    if not ok then return false,err end
    return true,payload.requestId
end
function Client.requestFlow(player,sourceId,targetId,amount,minimumPressure)
    if type(sendClientCommand)~="function" then return false,"sendClientCommand unavailable" end
    local value=tonumber(amount)
    if type(sourceId)~="string" or type(targetId)~="string" or not value or value<=0 then
        return false,"invalid flow request"
    end
    local payload={requestId=nextId(),sourceId=sourceId,targetId=targetId,amount=value,
        minimumPressure=math.max(0,tonumber(minimumPressure) or 0)}
    local ok,err=pcall(sendClientCommand,player,Commands.MODULE,Commands.FLOW,payload)
    if not ok then return false,err end
    return true,payload.requestId
end
function Client.configureDemand(player,sourceId,targetId,amount,intervalHours)
    if type(sendClientCommand)~="function"then return false,"sendClientCommand unavailable"end
    local value,interval=tonumber(amount),tonumber(intervalHours)
    if not player or type(sourceId)~="string"or type(targetId)~="string"or not value or value<=0
        or not interval or interval<=0 then return false,"invalid demand request"end
    local payload={requestId=nextId(),sourceId=sourceId,targetId=targetId,amount=value,intervalHours=interval}
    local ok,err=pcall(sendClientCommand,player,Commands.MODULE,Commands.SCHEDULE_DEMAND,payload)
    if not ok then return false,err end
    return true,payload.requestId
end
function Client.cancelDemand(player,sourceId,targetId)
    if type(sendClientCommand)~="function"then return false,"sendClientCommand unavailable"end
    if not player or type(sourceId)~="string"or type(targetId)~="string"then return false,"invalid demand request"end
    local payload={requestId=nextId(),sourceId=sourceId,targetId=targetId}
    local ok,err=pcall(sendClientCommand,player,Commands.MODULE,Commands.CANCEL_DEMAND,payload)
    if not ok then return false,err end
    return true,payload.requestId
end
function Client.requestSediment(player,operation,nodeId,generation,extra)
    if not player or type(sendClientCommand)~="function"or type(getTimestampMs)~="function"then return false,"sediment command unavailable"end
    local now=getTimestampMs()
    if type(now)~="number"or now~=now or math.abs(now)==math.huge then return false,"sediment clock unavailable"end
    counter=counter+1
    local payload={requestId="sediment:"..tostring(now)..":"..tostring(counter),
        operation=operation,nodeId=nodeId,expectedGeneration=generation}
    if type(extra)=="table"then
        for _,key in ipairs({"targetId","mediaId","itemId","x","y","z"})do payload[key]=extra[key]end
    end
    local pendingCount=0;for id,pending in pairs(Client.PendingSediment)do
        if now-pending.at>30000 then Client.PendingSediment[id]=nil else pendingCount=pendingCount+1 end
    end
    if pendingCount>=Client.MAX_HISTORY then return false,"sediment request limit reached"end
    Client.PendingSediment[payload.requestId]={nodeId=nodeId,at=now}
    local ok,err=pcall(sendClientCommand,player,Commands.MODULE,Commands.SEDIMENT,payload)
    if not ok then Client.PendingSediment[payload.requestId]=nil end
    return ok,ok and payload.requestId or err
end
function Client.receive(module,command,args)
    if module~=Commands.MODULE or type(args)~="table" then return false end
    if command==Commands.RESULT then
        local pending=Client.PendingSediment[args.requestId]
        if pending then
            Client.PendingSediment[args.requestId]=nil
            append(Client.SedimentResults,{nodeId=pending.nodeId or args.proposal and args.proposal.nodeId,ok=args.ok==true})
        end
        append(Client.Results,args); return true
    end
    if command==Commands.DELTA then append(Client.Deltas,args); return true end
    if command==Commands.SNAPSHOT then
        local current=Client.Snapshots[args.networkId]
        if args.cursor==nil then
            current={revision=args.revision,nodes={},edges={},complete=false,nextCursor=nil}
            Client.Snapshots[args.networkId]=current
        elseif not current or current.revision~=args.revision or current.nextCursor~=args.cursor then
            return false
        end
        for _,node in ipairs(type(args.nodes)=="table" and args.nodes or {}) do current.nodes[node.id]=node end
        for _,edge in ipairs(type(args.edges)=="table" and args.edges or {}) do
            current.edges[edge.a.."\0"..edge.b]=edge
        end
        current.nextCursor=args.nextCursor; current.complete=args.complete==true
        local pending=Client.PendingSnapshots[args.networkId]
        if pending then
            pending.pages=pending.pages+1
            if pending.pages>Client.MAX_SNAPSHOT_PAGES then completePending(args.networkId,nil,"snapshot page limit exceeded")
            elseif current.complete then completePending(args.networkId,current)
            elseif type(current.nextCursor)=="string"then
                pending.cursor=current.nextCursor;pending.revision=current.revision;pending.needsContinue=true
            else completePending(args.networkId,nil,"snapshot continuation unavailable")end
        end
        return true
    end
    if command==Commands.SNAPSHOT_ERROR then
        completePending(tostring(args.networkId or""),nil,tostring(args.reason or"snapshot rejected"))
        return true
    end
    return false
end
if Events and Events.OnServerCommand then Events.OnServerCommand.Add(Client.receive) end
if Events and Events.OnTick then Events.OnTick.Add(Client.pumpSnapshots)end
waterWorks.CommandClient=Client
return Client
