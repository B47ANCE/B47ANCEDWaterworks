local waterWorks=rawget(_G,"waterWorks")or require "waterWorks/API"
local Condition=waterWorks.Condition or require "waterWorks/Condition"
local Iteration=require "waterWorks/Iteration"
local Maintenance={PATCH_TYPE="waterWorks.InfrastructurePatchKit",MAX_ITEMS=512,MAX_RECOVERY=128}
local locks={}

local function call(object,name,...)
    local ok,fn=pcall(function()return object and object[name]end)
    if not ok or type(fn)~="function"then return nil,false end
    local called,value=pcall(fn,object,...);if called then return value,true end;return nil,false
end
local function listEach(list,callback)
    if type(list)=="table"then
        local count=0;for _,v in pairs(list)do count=count+1;if count>Maintenance.MAX_ITEMS then return nil end
            if callback(v)==false then return false end end;return true
    end
    local size,ok=call(list,"size");if not ok then return nil end
    for i=0,math.min(Maintenance.MAX_ITEMS,tonumber(size)or 0)-1 do
        local value,got=call(list,"get",i);if got and callback(value)==false then return false end
    end
    return true
end
local function findKit(player,itemId)
    local root,got=call(player,"getInventory");if not got or not root then return nil,"inventory unavailable"end
    local queue={root};local head,visited=1,0
    while head<=#queue and visited<Maintenance.MAX_ITEMS do
        local container=queue[head];head=head+1
        local items=call(container,"getItems")
        listEach(items,function(item)
            visited=visited+1;if visited>Maintenance.MAX_ITEMS then return false end
            local id,idOk=call(item,"getID");local kind,kindOk=call(item,"getFullType")
            local owner,ownerOk=call(item,"getContainer")
            if idOk and kindOk and ownerOk and owner==container and tostring(id)==tostring(itemId)
                and kind==Maintenance.PATCH_TYPE then return false,item end
            local nested,nestedOk=call(item,"getInventory");if nestedOk and nested then queue[#queue+1]=nested end
        end)
        -- listEach cannot return a second callback value under Kahlua; resolve
        -- the exact ID in a bounded second pass over this one container.
        local found=nil
        listEach(items,function(item)
            local id,idOk=call(item,"getID");local kind,kindOk=call(item,"getFullType");local owner,ownerOk=call(item,"getContainer")
            if idOk and kindOk and ownerOk and owner==container and tostring(id)==tostring(itemId)
                and kind==Maintenance.PATCH_TYPE then found=item;return false end
        end)
        if found then return found,container end
    end
    return nil,visited>=Maintenance.MAX_ITEMS and"inventory search budget exceeded"or"patch kit not found"
end
local function validRecoveryRecord(value)
    return type(value)=="table"and value.schemaVersion==1 and value.requiresInspection==true
end
local function recovery(store,create)
    if type(store)~="table"then return nil,"registry store required"end
    local value=store.infrastructureMaintenanceRecovery
    if value==nil and create then
        value={};store.infrastructureMaintenanceRecovery=value
    end
    if value==nil then return nil end
    if type(value)~="table"then return nil,"malformed maintenance recovery registry"end
    for nodeId,record in pairs(value)do
        if type(nodeId)~="string"or nodeId==""or not validRecoveryRecord(record)then
            return nil,"unsupported maintenance recovery schema"
        end
    end
    return value
end
local function recoveryCount(value)local n=0;for _ in pairs(value)do n=n+1 end;return n end
local function removeKit(player,item,container)
    local present,checked=call(container,"contains",item);if not checked or present~=true then return false,"patch kit ownership changed"end
    call(player,"removeFromHands",item);call(container,"Remove",item)
    local remains,verified=call(container,"contains",item)
    if verified and remains==false then
        if type(sendRemoveItemFromContainer)=="function"then pcall(sendRemoveItemFromContainer,container,item)end
        return true
    end
    if verified and remains==true then return false,"patch kit removal rejected"end
    return nil,"patch kit removal outcome uncertain"
end
function Maintenance.repair(store,nodeId,player,itemId,operationId)
    if type(isClient)=="function"and isClient()==true then return false,"non-authority"end
    if type(nodeId)~="string"or nodeId==""or type(operationId)~="string"or operationId==""then return false,"repair identity required"end
    if locks[nodeId]then return false,"maintenance node busy"end
    local recoveries,recoveryErr=recovery(store,true);if not recoveries then return false,recoveryErr end
    if recoveries[nodeId]then return false,"maintenance recovery inspection required"end
    if recoveryCount(recoveries)>=Maintenance.MAX_RECOVERY then return false,"maintenance recovery registry full"end
    local before,beforeErr=Condition.inspect(store,nodeId);if not before then return false,beforeErr end
    if before.condition>=1 and before.leakRatePerHour<=0 then return false,"infrastructure does not need repair"end
    local kit,container=findKit(player,itemId);if not kit then return false,container end
    local md=call(kit,"getModData");if type(md)~="table"then return false,"patch kit has no persistent state"end
    if md.waterWorksMaintenanceRecovery~=nil then return false,"patch kit requires recovery inspection"end
    md.waterWorksMaintenanceRecovery={schemaVersion=1,operationId=operationId,nodeId=nodeId,status="reserved"}
    call(kit,"transmitModData");locks[nodeId]=operationId
    local ok,result,details=Condition.repairTransaction(store,nodeId,.25,5,function()
        return removeKit(player,kit,container)
    end)
    locks[nodeId]=nil
    if ok then
        return true,{nodeId=nodeId,operationId=operationId,conditionBefore=before.condition,
            conditionAfter=result.condition,leakBefore=before.leakRatePerHour,
            leakAfter=result.leakRatePerHour,kitId=tostring(itemId)}
    end
    if details and details.rolledBack then
        md.waterWorksMaintenanceRecovery=nil;call(kit,"transmitModData")
    elseif details and details.uncertain then
        recoveries[nodeId]={schemaVersion=1,operationId=operationId,itemId=tostring(itemId),
            conditionBefore=before.condition,leakBefore=before.leakRatePerHour,
            conditionAfter=details.state.condition,leakAfter=details.state.leakRatePerHour,
            requiresInspection=true,reason=tostring(result)}
    end
    return false,result,details
end
function Maintenance.inspectRecovery(store,nodeId)
    local values,err=recovery(store,false);if err then return nil,err end
    local value=values and values[nodeId]or nil
    if not value then return nil end;local result={};for k,v in pairs(value)do result[k]=v end;return result
end
function Maintenance.listRecoveries(store,cursor,limit)
    local values,err=recovery(store,false);if err then return nil,err end;values=values or{}
    limit=math.max(1,math.min(32,math.floor(tonumber(limit)or 32)))
    if cursor~=nil and(type(cursor)~="string"or not values[cursor])then return nil,"invalid recovery cursor"end
    local rows={};local current=cursor;local nextCursor=nil
    for _=1,limit do
        local id,value=Iteration.nextEntry(values,current);if not id then nextCursor=nil;break end
        current=id;nextCursor=id
        local row={nodeId=id};for _,key in ipairs({"schemaVersion","operationId","itemId","conditionBefore",
            "leakBefore","conditionAfter","leakAfter","requiresInspection","reason"})do row[key]=value[key]end
        rows[#rows+1]=row
    end
    if Iteration.nextEntry(values,nextCursor)==nil then nextCursor=nil end
    return {schemaVersion=1,entries=rows,cursor=cursor,nextCursor=nextCursor,limit=limit}
end
function Maintenance.resolveRecovery(store,nodeId,mode)
    if type(isClient)=="function"and isClient()==true then return false,"non-authority"end
    local values,err=recovery(store,false);if err then return false,err end
    local record=values and values[nodeId];if not record then return false,"maintenance recovery unavailable"end
    local ok,result=Condition.resolveRepairRecovery(store,nodeId,record,mode);if not ok then return false,result end
    values[nodeId]=nil
    return true,{nodeId=nodeId,operationId=record.operationId,resolution=mode,state=result}
end
waterWorks.Maintenance=Maintenance;waterWorks.repairWithPatchKit=Maintenance.repair
waterWorks.listMaintenanceRecoveries=Maintenance.listRecoveries
waterWorks.resolveMaintenanceRecovery=Maintenance.resolveRecovery
return Maintenance
