local waterWorks=rawget(_G,"waterWorks") or {}
local Network=waterWorks.Network or require "waterWorks/Network"
local Registry=waterWorks.Registry or require "waterWorks/Registry"
local Connections={MAX_VALIDATORS=32,DEFAULT_NODE_DISTANCE=1.5,MAX_NODE_DISTANCE=4,
    DEFAULT_ACTOR_REACH=3,MAX_ACTOR_REACH=8}
local validators={}
local validatorCount=0
local locks={}

local function authoritative()
    return not (type(isClient)=="function" and isClient()==true)
end
local function coordinate(value,key)
    if type(value)=="table" and type(value[key])=="number" then return value[key] end
    if not value then return nil end
    local ok,method=pcall(function() return value["get"..key:upper()] end)
    if not ok or type(method)~="function" then return nil end
    local called,result=pcall(method,value); return called and tonumber(result) or nil
end
local function position(value)
    local x,y,z=coordinate(value,"x"),coordinate(value,"y"),coordinate(value,"z")
    if not x or not y or not z then return nil end
    return {x=x,y=y,z=z}
end
local function distance(a,b)
    local dx,dy,dz=a.x-b.x,a.y-b.y,(a.z-b.z)*3
    return math.sqrt(dx*dx+dy*dy+dz*dz)
end
local function edgeId(a,b) if a>b then a,b=b,a end; return a.."\0"..b end
local function orderedValidators()
    local result={}; for _,definition in pairs(validators) do result[#result+1]=definition end
    table.sort(result,function(a,b)
        local ap,bp=tonumber(a.priority) or 0,tonumber(b.priority) or 0
        return ap==bp and a.id<b.id or ap>bp
    end)
    return result
end
local function resolve(store,nodeId)
    if type(store)~="table" or type(store.nodeIndex)~="table" then return nil,"registry store required" end
    local index=store.nodeIndex[nodeId]; if not index then return nil,"unknown node" end
    local network=store.networks and store.networks[index.networkId]
    local node=network and network.nodes and network.nodes[nodeId]
    if not node then return nil,"orphan node index" end
    local object=Registry.getRuntimeObject(store,nodeId)
    if not object then return nil,"node not loaded" end
    return {index=index,network=network,node=node,object=object}
end
local function limits(context)
    context=type(context)=="table" and context or {}
    local node=math.max(0.1,math.min(Connections.MAX_NODE_DISTANCE,
        tonumber(context.maxNodeDistance) or Connections.DEFAULT_NODE_DISTANCE))
    local actor=math.max(0.1,math.min(Connections.MAX_ACTOR_REACH,
        tonumber(context.maxActorReach) or Connections.DEFAULT_ACTOR_REACH))
    return node,actor
end

function Connections.registerValidator(definition)
    assert(type(definition)=="table" and type(definition.id)=="string" and definition.id~="","validator id required")
    assert(type(definition.validate)=="function","validator callback required")
    assert(not validators[definition.id],"duplicate connection validator: "..definition.id)
    assert(validatorCount<Connections.MAX_VALIDATORS,"connection validator limit reached")
    validators[definition.id]={id=definition.id,priority=tonumber(definition.priority) or 0,validate=definition.validate}
    validatorCount=validatorCount+1
    return validators[definition.id]
end

function Connections.preview(store,operation,a,b,context)
    if operation~="connect" and operation~="disconnect" then return nil,"unsupported connection operation" end
    if type(a)~="string" or type(b)~="string" or a==b then return nil,"two distinct node ids required" end
    context=type(context)=="table" and context or {}
    local left,leftErr=resolve(store,a); if not left then return nil,leftErr end
    local right,rightErr=resolve(store,b); if not right then return nil,rightErr end
    if left.index.networkId~=right.index.networkId or left.network~=right.network then return nil,"nodes belong to different networks" end
    if left.node.channel~=right.node.channel then return nil,"channel mismatch" end
    local leftPosition,rightPosition=position(left.node),position(right.node)
    local actorPosition=position(context.actor)
    if not leftPosition or not rightPosition then return nil,"node position unavailable" end
    if not actorPosition then return nil,"actor position unavailable" end
    local maxNode,maxActor=limits(context)
    local separation=distance(leftPosition,rightPosition)
    if separation>maxNode then return nil,"nodes are too far apart" end
    if math.min(distance(actorPosition,leftPosition),distance(actorPosition,rightPosition))>maxActor then
        return nil,"actor is out of reach"
    end
    local linked=left.network.adjacency[a] and left.network.adjacency[a][b]==true
    if operation=="connect" and linked then return nil,"already connected" end
    if operation=="disconnect" and not linked then return nil,"edge not found" end
    local proposal={operation=operation,nodeA=a,nodeB=b,networkId=left.index.networkId,
        separation=separation,maxNodeDistance=maxNode,maxActorReach=maxActor,
        objectA=left.object,objectB=right.object,nodeDefinitionA=left.node,nodeDefinitionB=right.node}
    for _,definition in ipairs(orderedValidators()) do
        local ok,allowed,reason=pcall(definition.validate,proposal,context)
        if not ok then return nil,"connection validator failed: "..definition.id end
        if allowed~=true then return nil,reason or ("connection rejected by "..definition.id) end
    end
    proposal.objectA=nil; proposal.objectB=nil
    proposal.nodeDefinitionA=nil; proposal.nodeDefinitionB=nil
    return proposal,left.network
end

function Connections.request(store,operation,a,b,context)
    if not authoritative() then return false,"non-authority" end
    local proposal,networkOrError=Connections.preview(store,operation,a,b,context)
    if not proposal then return false,networkOrError end
    local id=edgeId(a,b); if locks[id] then return false,"edge busy" end
    locks[id]=operation
    local ok,result
    if operation=="connect" then ok,result=Network.connect(networkOrError,a,b)
    else ok,result=Network.disconnect(networkOrError,a,b) end
    locks[id]=nil
    if not ok then return false,result end
    proposal.revision=networkOrError.revision
    return true,proposal
end

function Connections.inspectEdge(store,a,b)
    if type(store)~="table" or type(store.nodeIndex)~="table" then return nil,"registry store required" end
    local left,right=store.nodeIndex[a],store.nodeIndex[b]
    if not left or not right or left.networkId~=right.networkId then return nil,"edge nodes unavailable" end
    local network=store.networks[left.networkId]
    if not network or not network.nodes[a] or not network.nodes[b] then return nil,"edge nodes unavailable" end
    return {nodeA=a,nodeB=b,networkId=left.networkId,
        connected=network.adjacency[a] and network.adjacency[a][b]==true or false,
        busy=locks[edgeId(a,b)]~=nil,revision=network.revision}
end

Connections.Validators=validators
waterWorks.Connections=Connections
waterWorks.requestConnection=Connections.request
_G.waterWorks=waterWorks
return Connections
