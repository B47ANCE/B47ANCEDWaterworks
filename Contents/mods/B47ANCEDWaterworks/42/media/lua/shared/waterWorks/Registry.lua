local waterWorks=rawget(_G,"waterWorks") or {}
local Network=waterWorks.Network or require "waterWorks/Network"
local Iteration=require "waterWorks/Iteration"
local Registry={SCHEMA_VERSION=1,STORE_KEY="waterWorks.NetworkRegistry.v1",MAX_PROVIDERS=64,
    MAX_NETWORKS=256,MAX_NODES=65536}
local providers={}
local providerCount=0
local runtime=setmetatable({},{__mode="k"})
local attachedStore=nil

local function authoritative()
    return not (type(isClient)=="function" and isClient()==true)
end
local function validId(value,max)
    return type(value)=="string" and value~="" and #value<=(max or 128) and not value:find("[%c]",1)
end
local function count(value)
    local result=0; for _ in pairs(type(value)=="table" and value or {}) do result=result+1 end; return result
end
local function runtimeFor(store)
    local value=runtime[store]
    if not value then value={objects=setmetatable({},{__mode="v"}),nodeByObject=setmetatable({},{__mode="k"})}; runtime[store]=value end
    return value
end
local function orderedProviders()
    local result={}
    for _,definition in pairs(providers) do result[#result+1]=definition end
    table.sort(result,function(a,b)
        local ap,bp=tonumber(a.priority) or 0,tonumber(b.priority) or 0
        return ap==bp and a.id<b.id or ap>bp
    end)
    return result
end
local function safeCall(callback,...)
    local ok,a,b=pcall(callback,...)
    if not ok then return nil,"provider callback failed" end
    return a,b
end
local function normalizeDescriptor(provider,descriptor)
    if type(descriptor)~="table" then return nil,"provider descriptor required" end
    local networkId=tostring(descriptor.networkId or descriptor.channel or "WATER")
    local stableKey=descriptor.stableKey
    if stableKey==nil and descriptor.x~=nil and descriptor.y~=nil and descriptor.z~=nil then
        stableKey=table.concat({tostring(descriptor.x),tostring(descriptor.y),tostring(descriptor.z),
            tostring(descriptor.slot or provider.id)},":")
    end
    stableKey=tostring(stableKey or "")
    if not validId(networkId,128) then return nil,"valid network id required" end
    if not validId(stableKey,192) then return nil,"stable object key required" end
    local nodeId=provider.id..":"..stableKey
    if #nodeId>Network.MAX_ID_LENGTH then return nil,"derived node id too long" end
    local node={id=nodeId,kind=tostring(descriptor.kind or "junction"),
        channel=tostring(descriptor.channel or "WATER"),enabled=descriptor.enabled~=false}
    for _,key in ipairs({"x","y","z"}) do node[key]=descriptor[key] end
    return {networkId=networkId,node=node,providerId=provider.id,stableKey=stableKey}
end
local function validateStore(store)
    if type(store)~="table" or store.schemaVersion~=Registry.SCHEMA_VERSION then return false,"unsupported registry schema" end
    if type(store.networks)~="table" or type(store.nodeIndex)~="table" then return false,"malformed registry" end
    return true
end

function Registry.newStore()
    return {schemaVersion=Registry.SCHEMA_VERSION,revision=0,networks={},nodeIndex={}}
end

function Registry.attachStore(store)
    if type(store)~="table" then return false,"registry store required" end
    if not Iteration.hasEntries(store) then
        local created=Registry.newStore(); for key,value in pairs(created) do store[key]=value end
    end
    local ok,err=validateStore(store); if not ok then return false,err end
    attachedStore=store; runtimeFor(store)
    return true,store
end

function Registry.getStore() return attachedStore end

function Registry.registerProvider(definition)
    assert(type(definition)=="table" and validId(definition.id,64),"provider id required")
    assert(type(definition.matches)=="function" and type(definition.describe)=="function","provider callbacks required")
    assert(not providers[definition.id],"duplicate B47ANCEDWaterworks provider: "..definition.id)
    assert(providerCount<Registry.MAX_PROVIDERS,"B47ANCEDWaterworks provider limit reached")
    local copy={id=definition.id,priority=tonumber(definition.priority) or 0,matches=definition.matches,
        describe=definition.describe,onAttach=definition.onAttach,onDetach=definition.onDetach}
    providers[copy.id]=copy; providerCount=providerCount+1
    return copy
end

function Registry.describeObject(object)
    if not object then return nil,"object required" end
    for _,provider in ipairs(orderedProviders()) do
        local matched,matchErr=safeCall(provider.matches,object)
        if matchErr then
            -- Isolate a broken third-party classifier and continue.
        elseif matched==true then
            local descriptor,describeErr=safeCall(provider.describe,object)
            if not descriptor then return nil,describeErr or "provider rejected object" end
            local normalized,normalizeErr=normalizeDescriptor(provider,descriptor)
            if not normalized then return nil,normalizeErr end
            normalized.provider=provider
            return normalized
        end
    end
    return nil,"no infrastructure provider"
end

local function ensureNetwork(store,id)
    local network=store.networks[id]
    if network then
        local ok,err=Network.validate(network); if not ok then return nil,err end
        return network
    end
    if count(store.networks)>=Registry.MAX_NETWORKS then return nil,"network limit reached" end
    network=Network.newState(); store.networks[id]=network
    return network
end

function Registry.attachObject(store,object)
    if not authoritative() then return false,"non-authority" end
    local ok,err=validateStore(store); if not ok then return false,err end
    local descriptor,describeErr=Registry.describeObject(object); if not descriptor then return false,describeErr end
    local index=store.nodeIndex[descriptor.node.id]
    local network
    if index then
        if index.networkId~=descriptor.networkId or index.providerId~=descriptor.providerId then
            return false,"stable node identity conflict"
        end
        network=store.networks[index.networkId]
        if not network or not network.nodes[descriptor.node.id] then return false,"orphan node index" end
    else
        if count(store.nodeIndex)>=Registry.MAX_NODES then return false,"node registry limit reached" end
        network,err=ensureNetwork(store,descriptor.networkId); if not network then return false,err end
        local added,addErr=Network.addNode(network,descriptor.node); if not added then return false,addErr end
        store.nodeIndex[descriptor.node.id]={networkId=descriptor.networkId,providerId=descriptor.providerId,
            stableKey=descriptor.stableKey}
        store.revision=store.revision+1
    end
    local live=runtimeFor(store)
    local prior=live.objects[descriptor.node.id]
    if prior and prior~=object then live.nodeByObject[prior]=nil end
    live.objects[descriptor.node.id]=object; live.nodeByObject[object]=descriptor.node.id
    if descriptor.provider.onAttach then safeCall(descriptor.provider.onAttach,object,descriptor.node,network) end
    return true,{nodeId=descriptor.node.id,networkId=descriptor.networkId,created=index==nil}
end

-- Lifecycle events may only restore nodes created by an explicit claim or
-- placement transaction. They must never turn arbitrary loaded fixtures or
-- dropped pumps into infrastructure merely because a provider recognizes them.
function Registry.reattachObject(store,object)
    if not authoritative() then return false,"non-authority"end
    local ok,err=validateStore(store);if not ok then return false,err end
    local descriptor,describeErr=Registry.describeObject(object);if not descriptor then return false,describeErr end
    if not store.nodeIndex[descriptor.node.id]then return false,"object has no persistent node"end
    return Registry.attachObject(store,object)
end

function Registry.detachObject(store,object)
    local ok,err=validateStore(store); if not ok then return false,err end
    local live=runtimeFor(store); local nodeId=live.nodeByObject[object]
    if not nodeId then return false,"object not attached" end
    local index=store.nodeIndex[nodeId]; local provider=index and providers[index.providerId]
    live.nodeByObject[object]=nil
    if live.objects[nodeId]==object then live.objects[nodeId]=nil end
    if provider and provider.onDetach then safeCall(provider.onDetach,object,nodeId) end
    return true,nodeId
end

function Registry.decommissionNode(store,nodeId)
    if not authoritative() then return false,"non-authority" end
    local ok,err=validateStore(store); if not ok then return false,err end
    local index=store.nodeIndex[nodeId]; if not index then return false,"unknown node" end
    local network=store.networks[index.networkId]; if not network then return false,"orphan node index" end
    local removed,removeErr=Network.removeNode(network,nodeId); if not removed then return false,removeErr end
    local live=runtimeFor(store); local object=live.objects[nodeId]
    if object then live.nodeByObject[object]=nil end
    live.objects[nodeId]=nil; store.nodeIndex[nodeId]=nil; store.revision=store.revision+1
    if not Iteration.hasEntries(network.nodes) then store.networks[index.networkId]=nil end
    return true
end

function Registry.getRuntimeObject(store,nodeId)
    local ok,err=validateStore(store); if not ok then return nil,err end
    if not store.nodeIndex[nodeId] then return nil,"unknown node" end
    return runtimeFor(store).objects[nodeId]
end

function Registry.inspect(store)
    local ok,err=validateStore(store); if not ok then return nil,err end
    local live=runtimeFor(store); local attached=0
    for nodeId in pairs(store.nodeIndex) do if live.objects[nodeId]~=nil then attached=attached+1 end end
    return {schemaVersion=store.schemaVersion,revision=store.revision,networkCount=count(store.networks),
        nodeCount=count(store.nodeIndex),attachedCount=attached,providerCount=providerCount}
end

function Registry.validate(store)
    local ok,err=validateStore(store); if not ok then return false,err end
    for networkId,network in pairs(store.networks) do
        if not validId(networkId,128) then return false,"malformed network id" end
        local valid,networkErr=Network.validate(network); if not valid then return false,networkErr end
        for nodeId in pairs(network.nodes) do
            local index=store.nodeIndex[nodeId]
            if type(index)~="table" or index.networkId~=networkId or not providers[index.providerId] then
                return false,"missing node index"
            end
        end
    end
    for nodeId,index in pairs(store.nodeIndex) do
        local network=type(index)=="table" and store.networks[index.networkId] or nil
        if not network or not network.nodes[nodeId] then return false,"orphan node index" end
    end
    return true
end

Registry.Providers=providers
waterWorks.Registry=Registry
waterWorks.NETWORK_REGISTRY_KEY=Registry.STORE_KEY
_G.waterWorks=waterWorks
return Registry
