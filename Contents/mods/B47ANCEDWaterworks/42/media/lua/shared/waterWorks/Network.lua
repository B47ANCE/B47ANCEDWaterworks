local waterWorks=rawget(_G,"waterWorks") or {}
local Iteration=require "waterWorks/Iteration"
local Network={SCHEMA_VERSION=1,DEFAULT_MAX_DEGREE=8,MAX_MAX_DEGREE=16,MAX_ID_LENGTH=128}
local jobs=setmetatable({},{__mode="k"})

local function authoritative()
    return not (type(isClient)=="function" and isClient()==true)
end
local function integer(value)
    return type(value)=="number" and value==math.floor(value) and value~=math.huge and value~=-math.huge
end
local function validId(value)
    return type(value)=="string" and value~="" and #value<=Network.MAX_ID_LENGTH
        and not value:find("[%c]",1)
end
local function countEntries(value)
    local count=0
    for _ in pairs(type(value)=="table" and value or {}) do count=count+1 end
    return count
end
local function copyNode(definition)
    local node={id=definition.id,kind=tostring(definition.kind or "junction"),
        channel=tostring(definition.channel or "WATER"),enabled=definition.enabled~=false}
    for _,key in ipairs({"x","y","z"}) do
        if definition[key]~=nil then
            if not integer(definition[key]) then return nil,key.." must be an integer" end
            node[key]=definition[key]
        end
    end
    return node
end
local function stateOk(state)
    if type(state)~="table" or state.schemaVersion~=Network.SCHEMA_VERSION then return false,"unsupported network schema" end
    if type(state.nodes)~="table" or type(state.adjacency)~="table" then return false,"malformed network state" end
    if not integer(state.revision) or state.revision<0 then return false,"malformed network revision" end
    if not integer(state.maxDegree) or state.maxDegree<1 or state.maxDegree>Network.MAX_MAX_DEGREE then return false,"malformed degree limit" end
    return true
end
local function mutate(state)
    state.revision=state.revision+1
    state.topologyDirty=true
    state.topologyRevision=nil
    jobs[state]=nil
end
local function canMutate(state)
    if not authoritative() then return false,"non-authority" end
    return stateOk(state)
end

function Network.newState(options)
    options=type(options)=="table" and options or {}
    local maxDegree=math.floor(tonumber(options.maxDegree) or Network.DEFAULT_MAX_DEGREE)
    maxDegree=math.max(1,math.min(Network.MAX_MAX_DEGREE,maxDegree))
    return {schemaVersion=Network.SCHEMA_VERSION,revision=0,maxDegree=maxDegree,nodes={},adjacency={},
        componentByNode={},componentCount=0,topologyDirty=false,topologyRevision=0}
end

function Network.addNode(state,definition)
    local ok,err=canMutate(state); if not ok then return false,err end
    if type(definition)~="table" or not validId(definition.id) then return false,"valid node id required" end
    if state.nodes[definition.id] then return false,"duplicate node" end
    local node,nodeErr=copyNode(definition); if not node then return false,nodeErr end
    state.nodes[node.id]=node; state.adjacency[node.id]={}; mutate(state)
    return true,node
end

function Network.removeNode(state,id)
    local ok,err=canMutate(state); if not ok then return false,err end
    if not state.nodes[id] then return false,"unknown node" end
    for neighbor in pairs(state.adjacency[id] or {}) do
        if type(state.adjacency[neighbor])=="table" then state.adjacency[neighbor][id]=nil end
    end
    state.nodes[id]=nil; state.adjacency[id]=nil; mutate(state)
    return true
end

function Network.connect(state,a,b)
    local ok,err=canMutate(state); if not ok then return false,err end
    if not validId(a) or not validId(b) or a==b then return false,"two distinct valid node ids required" end
    local na,nb=state.nodes[a],state.nodes[b]
    if not na or not nb then return false,"unknown node" end
    if na.channel~=nb.channel then return false,"channel mismatch" end
    local aa,ab=state.adjacency[a],state.adjacency[b]
    if type(aa)~="table" or type(ab)~="table" then return false,"malformed adjacency" end
    if aa[b] then return true,"already connected" end
    if countEntries(aa)>=state.maxDegree or countEntries(ab)>=state.maxDegree then return false,"degree limit reached" end
    aa[b]=true; ab[a]=true; mutate(state)
    return true
end

function Network.disconnect(state,a,b)
    local ok,err=canMutate(state); if not ok then return false,err end
    local aa,ab=state.adjacency[a],state.adjacency[b]
    if type(aa)~="table" or type(ab)~="table" or not aa[b] or not ab[a] then return false,"edge not found" end
    aa[b]=nil; ab[a]=nil; mutate(state)
    return true
end

function Network.setNodeEnabled(state,id,enabled)
    local ok,err=canMutate(state); if not ok then return false,err end
    local node=state.nodes[id]; if not node then return false,"unknown node" end
    local value=enabled~=false
    if node.enabled==value then return true,node end
    node.enabled=value; mutate(state)
    return true,node
end

local function startJob(state)
    local job={revision=state.revision,phase="discover",cursor=nil,nodeIds={},componentByNode={},
        componentCount=0,scanIndex=1,queue={},queueHead=1,activeComponent=nil,workDone=0}
    jobs[state]=job
    return job
end
local function publish(state,job)
    if state.revision~=job.revision then jobs[state]=nil; return false end
    state.componentByNode=job.componentByNode
    state.componentCount=job.componentCount
    state.topologyRevision=job.revision
    state.topologyDirty=false
    jobs[state]=nil
    return true
end

function Network.stepTopology(state,budget)
    local ok,err=stateOk(state); if not ok then return nil,err end
    budget=math.floor(tonumber(budget) or 0)
    if budget<1 then return nil,"positive work budget required" end
    if not state.topologyDirty and state.topologyRevision==state.revision then
        return {complete=true,work=0,revision=state.revision,componentCount=state.componentCount}
    end
    local job=jobs[state]
    if not job or job.revision~=state.revision then job=startJob(state) end
    local work=0
    while work<budget do
        if job.phase=="discover" then
            local id=Iteration.nextEntry(state.nodes,job.cursor)
            if id==nil then job.phase="components"
            else
                job.cursor=id; job.nodeIds[#job.nodeIds+1]=id; work=work+1
            end
        elseif job.queueHead<=#job.queue then
            local id=job.queue[job.queueHead]; job.queueHead=job.queueHead+1
            local node=state.nodes[id]
            if node and node.enabled~=false then
                for neighbor in pairs(state.adjacency[id] or {}) do
                    local other=state.nodes[neighbor]
                    if other and other.enabled~=false and not job.componentByNode[neighbor] then
                        job.componentByNode[neighbor]=job.activeComponent
                        job.queue[#job.queue+1]=neighbor
                    end
                end
            end
            work=work+1
        elseif job.scanIndex<=#job.nodeIds then
            local id=job.nodeIds[job.scanIndex]; job.scanIndex=job.scanIndex+1
            local node=state.nodes[id]
            if node and not job.componentByNode[id] then
                job.componentCount=job.componentCount+1
                job.activeComponent=job.componentCount
                job.componentByNode[id]=job.activeComponent
                job.queue={id}; job.queueHead=1
            end
            work=work+1
        else
            publish(state,job)
            return {complete=true,work=work,revision=state.revision,componentCount=state.componentCount}
        end
    end
    job.workDone=job.workDone+work
    return {complete=false,work=work,revision=job.revision,phase=job.phase,
        discovered=#job.nodeIds,components=job.componentCount}
end

function Network.getNeighbors(state,id)
    local ok,err=stateOk(state); if not ok then return nil,err end
    if not state.nodes[id] then return nil,"unknown node" end
    local result={}
    for neighbor in pairs(state.adjacency[id] or {}) do result[#result+1]=neighbor end
    table.sort(result)
    return result
end

function Network.getComponent(state,id)
    local ok,err=stateOk(state); if not ok then return nil,err end
    if not state.nodes[id] then return nil,"unknown node" end
    if state.topologyDirty or state.topologyRevision~=state.revision then return nil,"topology pending" end
    return state.componentByNode[id]
end

function Network.areConnected(state,a,b)
    local ca,err=Network.getComponent(state,a); if not ca then return nil,err end
    local cb,otherErr=Network.getComponent(state,b); if not cb then return nil,otherErr end
    return ca==cb
end

function Network.inspect(state)
    local ok,err=stateOk(state); if not ok then return nil,err end
    local edgeEnds=0
    for id in pairs(state.nodes) do edgeEnds=edgeEnds+countEntries(state.adjacency[id]) end
    local job=jobs[state]
    return {schemaVersion=state.schemaVersion,revision=state.revision,nodeCount=countEntries(state.nodes),
        edgeCount=math.floor(edgeEnds/2),maxDegree=state.maxDegree,topologyDirty=state.topologyDirty==true,
        topologyRevision=state.topologyRevision,componentCount=state.componentCount or 0,
        rebuildPhase=job and job.phase or nil,rebuildRevision=job and job.revision or nil}
end

function Network.validate(state)
    local ok,err=stateOk(state); if not ok then return false,err end
    for id,node in pairs(state.nodes) do
        if not validId(id) or type(node)~="table" or node.id~=id or type(node.channel)~="string" then return false,"malformed node" end
        local edges=state.adjacency[id]
        if type(edges)~="table" or countEntries(edges)>state.maxDegree then return false,"malformed adjacency" end
        for neighbor,linked in pairs(edges) do
            if linked~=true or not state.nodes[neighbor] or type(state.adjacency[neighbor])~="table"
                or state.adjacency[neighbor][id]~=true then return false,"asymmetric edge" end
            if state.nodes[neighbor].channel~=node.channel then return false,"cross-channel edge" end
        end
    end
    for id in pairs(state.adjacency) do if not state.nodes[id] then return false,"orphan adjacency" end end
    return true
end

waterWorks.Network=Network
waterWorks.newNetwork=Network.newState
_G.waterWorks=waterWorks
return Network
