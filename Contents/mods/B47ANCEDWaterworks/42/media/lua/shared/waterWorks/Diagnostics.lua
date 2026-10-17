local waterWorks=rawget(_G,"waterWorks") or {}
local Registry=waterWorks.Registry or require "waterWorks/Registry"
local Network=waterWorks.Network or require "waterWorks/Network"
local Diagnostics={MAX_PAGE=32,MAX_TEXT=8192}

local PERSISTENT_FIELDS={
    {id="scheduledDemands",schema=1,required={"entries"}},
    {id="infrastructureCondition",schema=1,required={"entries"}},
    {id="thermalState",schema=1,required={"entries"}},
}
local OBJECT_FIELDS={
    {id="waterWorksQuality.v1",schema=1},
    {id="waterWorksTreatmentRecovery.v1",schema=1},
    {id="waterWorksDrainRecovery.v1",schema=1},
    {id="waterWorksTransferRecovery.v1",schema=1},
    {id="waterWorksInfrastructure.v1",schema=1},
    {id="waterWorksInlineValve.v1",schema=1},
}

local function bounded(value,maximum)
    value=tostring(value or "")
    return #value>maximum and value:sub(1,maximum) or value
end
local function authoritative()
    return not(type(isClient)=="function"and isClient()==true)
end
local function hasEntries(value)
    for _ in pairs(type(value)=="table"and value or{})do return true end
    return false
end
local function schemaStatus(value,current,required)
    if value==nil then return "missing"end
    if type(value)~="table"then return "malformed"end
    if value.schemaVersion==nil then return "missing-version"end
    if type(value.schemaVersion)~="number"then return "malformed"end
    if value.schemaVersion>current then return "future-version"end
    if value.schemaVersion<current then return "legacy-version"end
    for _,field in ipairs(required or{})do if type(value[field])~="table"then return "malformed"end end
    return "current"
end
local function modData(owner)
    if not owner then return nil end
    local ok,fn=pcall(function()return owner.getModData end)
    if not ok or type(fn)~="function"then return nil end
    local called,value=pcall(fn,owner);return called and type(value)=="table"and value or nil
end

function Diagnostics.inspect(store,options)
    options=type(options)=="table" and options or {}
    local registry,err=Registry.inspect(store); if not registry then return nil,err end
    local ids={}; for id in pairs(store.networks or {}) do ids[#ids+1]=id end; table.sort(ids)
    local cursor=math.max(0,math.floor(tonumber(options.cursor) or 0))
    local limit=math.max(1,math.min(Diagnostics.MAX_PAGE,math.floor(tonumber(options.limit) or Diagnostics.MAX_PAGE)))
    local rows={}; local totals={nodes=0,edges=0,components=0,dirty=0,errors=0}
    for _,id in ipairs(ids) do
        local inspected=Network.inspect(store.networks[id])
        if inspected then
            totals.nodes=totals.nodes+(tonumber(inspected.nodeCount) or 0)
            totals.edges=totals.edges+(tonumber(inspected.edgeCount) or 0)
            totals.components=totals.components+(tonumber(inspected.componentCount) or 0)
            if inspected.topologyDirty then totals.dirty=totals.dirty+1 end
        else totals.errors=totals.errors+1 end
    end
    local last=math.min(#ids,cursor+limit)
    for index=cursor+1,last do
        local id=ids[index]; local inspected,networkErr=Network.inspect(store.networks[id])
        rows[#rows+1]=inspected and {id=bounded(id,128),revision=inspected.revision,
            nodeCount=inspected.nodeCount,edgeCount=inspected.edgeCount,
            componentCount=inspected.componentCount,topologyDirty=inspected.topologyDirty,
            rebuildPhase=bounded(inspected.rebuildPhase,32)}
            or {id=bounded(id,128),error=bounded(networkErr or "inspection failed",160)}
    end
    local maintenanceRecovery=type(store.infrastructureMaintenanceRecovery)=="table"and store.infrastructureMaintenanceRecovery or{}
    local recoveryCount=0;for _ in pairs(maintenanceRecovery)do recoveryCount=recoveryCount+1 end
    totals.maintenanceRecoveries=recoveryCount
    return {schemaVersion=1,registry=registry,totals=totals,networks=rows,cursor=cursor,
        nextCursor=last<#ids and last or nil,totalNetworks=#ids,limit=limit}
end

function Diagnostics.report(store,options)
    local snapshot,err=Diagnostics.inspect(store,options); if not snapshot then return nil,err end
    local lines={string.format("B47ANCEDWaterworks networks=%d nodes=%d attached=%d edges=%d components=%d dirty=%d errors=%d maintenanceRecovery=%d",
        snapshot.totalNetworks,tonumber(snapshot.registry.nodeCount) or 0,tonumber(snapshot.registry.attachedCount) or 0,
        snapshot.totals.edges,snapshot.totals.components,snapshot.totals.dirty,snapshot.totals.errors,
        snapshot.totals.maintenanceRecoveries or 0)}
    for _,row in ipairs(snapshot.networks) do
        lines[#lines+1]=row.error and string.format("%s ERROR %s",row.id,row.error) or
            string.format("%s rev=%d nodes=%d edges=%d components=%d dirty=%s",row.id,
                tonumber(row.revision) or 0,tonumber(row.nodeCount) or 0,tonumber(row.edgeCount) or 0,
                tonumber(row.componentCount) or 0,tostring(row.topologyDirty==true))
    end
    local text=table.concat(lines,"\n"); if #text>Diagnostics.MAX_TEXT then text=text:sub(1,Diagnostics.MAX_TEXT) end
    return text,snapshot
end

-- Server-only, read-only schema inventory. It reports classifications and
-- stable identifiers, never the persistent tables themselves.
function Diagnostics.inspectPersistence(store,options)
    if not authoritative()then return nil,"non-authority"end
    options=type(options)=="table"and options or{}
    if type(store)~="table"then return nil,"registry store required"end
    local registryStatus
    if not hasEntries(store)then registryStatus="missing"
    else
        registryStatus=schemaStatus(store,Registry.SCHEMA_VERSION,{"networks","nodeIndex"})
        if registryStatus=="current"and Registry.validate(store)~=true then registryStatus="malformed"end
    end
    local ledgers={}
    for _,definition in ipairs(PERSISTENT_FIELDS)do
        local value=store[definition.id]
        ledgers[#ledgers+1]={id=definition.id,status=schemaStatus(value,definition.schema,definition.required),
            schemaVersion=type(value)=="table"and tonumber(value.schemaVersion)or nil}
    end
    local recoveries=store.infrastructureMaintenanceRecovery
    local recoveryIds={}
    if type(recoveries)=="table"then for id in pairs(recoveries)do recoveryIds[#recoveryIds+1]=tostring(id)end;table.sort(recoveryIds)end
    local recoveryStatus=recoveries==nil and"missing"or type(recoveries)~="table"and"malformed"or"current"
    if type(recoveries)=="table"then
        for _,id in ipairs(recoveryIds)do
            local status=schemaStatus(recoveries[id],1)
            if status~="current"or recoveries[id].requiresInspection~=true then recoveryStatus="mixed-unsupported";break end
        end
    end
    local cursor=math.max(0,math.floor(tonumber(options.cursor)or 0))
    local limit=math.max(1,math.min(Diagnostics.MAX_PAGE,math.floor(tonumber(options.limit)or Diagnostics.MAX_PAGE)))
    local records={};local last=math.min(#recoveryIds,cursor+limit)
    for index=cursor+1,last do
        local id=recoveryIds[index];local record=recoveries[id]
        records[#records+1]={id=bounded(id,128),status=schemaStatus(record,1),
            schemaVersion=type(record)=="table"and tonumber(record.schemaVersion)or nil,
            requiresInspection=type(record)=="table"and record.requiresInspection==true or false}
    end
    return {schemaVersion=1,registry={id=Registry.STORE_KEY,status=registryStatus,
        schemaVersion=tonumber(store.schemaVersion)},ledgers=ledgers,
        maintenanceRecovery={status=recoveryStatus,count=#recoveryIds,records=records,cursor=cursor,
            nextCursor=last<#recoveryIds and last or nil,limit=limit}}
end

function Diagnostics.inspectObjectPersistence(owner)
    if not authoritative()then return nil,"non-authority"end
    local data=modData(owner);if not data then return nil,"persistent object ModData required"end
    local rows={}
    for _,definition in ipairs(OBJECT_FIELDS)do
        local value=data[definition.id]
        rows[#rows+1]={id=definition.id,status=schemaStatus(value,definition.schema),
            schemaVersion=type(value)=="table"and tonumber(value.schemaVersion)or nil}
    end
    for _,id in ipairs({"waterWorksNetworkId","waterWorksPumpEnabled","waterWorksTreatmentEnabled","waterWorksTreatmentHistory"})do
        rows[#rows+1]={id=id,status=data[id]==nil and"missing"or"unversioned-present"}
    end
    return {schemaVersion=1,records=rows}
end

waterWorks.Diagnostics=Diagnostics; waterWorks.inspectNetworks=Diagnostics.inspect; waterWorks.reportNetworks=Diagnostics.report
waterWorks.inspectPersistence=Diagnostics.inspectPersistence
waterWorks.inspectObjectPersistence=Diagnostics.inspectObjectPersistence
_G.waterWorks=waterWorks
return Diagnostics
