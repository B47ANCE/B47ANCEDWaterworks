local waterWorks=rawget(_G,"waterWorks")or require "waterWorks/API"
local Filters=waterWorks.Filters or require "waterWorks/Filters"
local Transactions={SCHEMA_VERSION=1,STORE_KEY="filterOperations",MAX_OPERATIONS=128,MAX_STAGES=Filters.MAX_CHAIN_STAGES}
local providers={};local locks={}

local function authority()return not(type(isClient)=="function"and isClient()==true)end
local function valid(value,maximum)return type(value)=="string"and value~=""and#value<=(maximum or 128)and value:match("^[%w_.:%-]+$")~=nil end
local function finite(value)value=tonumber(value);return value and value==value and value~=math.huge and value~=-math.huge and value or nil end
local function close(a,b)return math.abs((tonumber(a)or-1)-(tonumber(b)or-2))<=0.000001 end
local function copy(value,depth)
    if type(value)~="table"then return value end;depth=(depth or 0)+1;if depth>5 then return nil end
    local result={};local count=0;for key,entry in pairs(value)do
        if(type(key)=="string"and#key<=64)or(type(key)=="number"and key>=1 and key<=32 and key%1==0)then
            if count<64 then result[key]=copy(entry,depth);count=count+1 end
        end
    end;return result
end
local function operationStore(store,create)
    if type(store)~="table"then return nil,"registry store required"end
    local value=store[Transactions.STORE_KEY]
    if value==nil and create then value={schemaVersion=1,records={},order={}};store[Transactions.STORE_KEY]=value end
    if type(value)~="table"or value.schemaVersion~=1 or type(value.records)~="table"or type(value.order)~="table"then
        return nil,"unsupported filter transaction store"
    end
    return value
end
local function fingerprint(request)
    local parts={tostring(request.amount),tostring(request.operationId)}
    for index,stage in ipairs(request.stages)do
        parts[#parts+1]=table.concat({index,stage.providerId,stage.stageId,stage.filterId},":")
    end
    return table.concat(parts,"|")
end
local function remember(store,record)
    while#store.order>=Transactions.MAX_OPERATIONS do
        local id=store.order[1];local old=store.records[id]
        if old and(old.status=="reserved"or old.status=="recovery")then return false,"filter transaction store full"end
        table.remove(store.order,1);store.records[id]=nil
    end
    store.records[record.operationId]=record;store.order[#store.order+1]=record.operationId
    return true
end
local function current(provider,stageId)
    local ok,object=pcall(provider.resolve,stageId);if not ok or not object then return nil,nil,"filter stage unavailable"end
    local inspected,state=pcall(provider.inspect,object)
    if not inspected or type(state)~="table"then return nil,nil,"filter stage state unavailable"end
    local remaining,condition=finite(state.remainingCapacity),finite(state.condition)
    if not remaining or remaining<0 or not condition or condition<0 or condition>1 then return nil,nil,"invalid filter stage state"end
    return object,{remainingCapacity=remaining,condition=condition,filterId=state.filterId}
end

function Transactions.registerProvider(definition)
    assert(type(definition)=="table"and valid(definition.id),"filter media provider id required")
    assert(type(definition.resolve)=="function"and type(definition.inspect)=="function"and type(definition.apply)=="function",
        "filter media provider callbacks required")
    assert(not providers[definition.id],"duplicate filter media provider: "..definition.id)
    providers[definition.id]={id=definition.id,resolve=definition.resolve,inspect=definition.inspect,apply=definition.apply};return{id=definition.id}
end

function Transactions.reserve(store,request)
    if not authority()then return false,"non-authority"end
    if type(request)~="table"or request.schemaVersion~=1 or not valid(request.operationId)or type(request.stages)~="table"then
        return false,"invalid filter transaction request"
    end
    local amount=finite(request.amount);if not amount or amount<=0 then return false,"positive finite filter amount required"end
    local count=0;for key in pairs(request.stages)do
        if type(key)~="number"or key<1 or key%1~=0 then return false,"filter stages must be a dense array"end
        count=count+1;if count>Transactions.MAX_STAGES then return false,"filter chain limit exceeded"end
    end
    if count<1 then return false,"at least one filter stage required"end
    for index=1,count do if request.stages[index]==nil then return false,"filter stages must be a dense array"end end
    local operations,err=operationStore(store,true);if not operations then return false,err end
    local signature=fingerprint(request);local replay=operations.records[request.operationId]
    if replay then
        if replay.fingerprint~=signature then return false,"operation id conflict"end
        return replay.status=="reserved"or replay.status=="committed",replay.status,copy(replay)
    end
    local seen={}
    for index,stage in ipairs(request.stages)do
        if type(stage)~="table"or not valid(stage.providerId)or not valid(stage.stageId)or not valid(stage.filterId)then
            return false,"invalid filter stage reference"
        end
        if not providers[stage.providerId]then return false,"filter media provider unavailable"end
        local key=stage.providerId..":"..stage.stageId
        if seen[key]then return false,"duplicate filter stage reference"end;seen[key]=true
        if locks[key]then return false,"filter stage busy"end
    end
    local stages,evaluationStages,acquired={},{},{}
    local function unlock()for _,key in ipairs(acquired)do locks[key]=nil end end
    for index,stage in ipairs(request.stages)do
        local lockKey=stage.providerId..":"..stage.stageId;local provider=providers[stage.providerId]
        local _,state,stateErr=current(provider,stage.stageId)
        if not state then unlock();return false,stateErr end
        if state.filterId~=nil and tostring(state.filterId)~=stage.filterId then unlock();return false,"filter identity changed"end
        acquired[#acquired+1]=lockKey;locks[lockKey]=request.operationId
        stages[index]={providerId=stage.providerId,stageId=stage.stageId,filterId=stage.filterId,before=state}
        evaluationStages[index]={filterId=stage.filterId,state=state}
    end
    local evaluated,evaluateErr=Filters.evaluateChain(evaluationStages,request.inputQuality,amount,request.context)
    unlock()
    if not evaluated then return false,evaluateErr end
    for index,result in ipairs(evaluated.stages)do stages[index].after={remainingCapacity=result.remainingCapacity,condition=result.condition}end
    local record={schemaVersion=1,operationId=request.operationId,fingerprint=signature,status="reserved",amount=amount,
        stages=stages,result={quality=evaluated.quality,stageCount=evaluated.stageCount}}
    local stored,storeErr=remember(operations,record);if not stored then operations.records[record.operationId]=nil;return false,storeErr end
    return true,"reserved",copy(record)
end

local function applyStage(stage,from,to,operationId)
    local provider=providers[stage.providerId];if not provider then return false,"filter media provider unavailable"end
    local object,state,err=current(provider,stage.stageId);if not state then return false,err end
    if not close(state.remainingCapacity,from.remainingCapacity)or not close(state.condition,from.condition)then return false,"filter stage state changed"end
    local ok,result=pcall(provider.apply,object,copy(from),copy(to),operationId)
    local _,verified= current(provider,stage.stageId)
    local atTarget=verified and close(verified.remainingCapacity,to.remainingCapacity)and close(verified.condition,to.condition)
    if ok and result==true and atTarget then return true end
    local unchanged=verified and close(verified.remainingCapacity,from.remainingCapacity)and close(verified.condition,from.condition)
    return false,(ok and result==true)and"filter media mutation unverified"or"filter media mutation failed",not unchanged
end

function Transactions.commit(store,operationId)
    if not authority()then return false,"non-authority"end
    local operations,err=operationStore(store,false);if not operations then return false,err end
    local record=operations.records[operationId];if not record then return false,"filter transaction unavailable"end
    if record.status=="committed"then return true,"committed",copy(record)end
    if record.status~="reserved"then return false,record.status,copy(record)end
    local acquired={};for _,stage in ipairs(record.stages)do
        local key=stage.providerId..":"..stage.stageId;if locks[key]then return false,"filter stage busy"end
        acquired[#acquired+1]=key
    end
    for _,key in ipairs(acquired)do locks[key]=operationId end
    local applied=0;local failure=nil;local uncertain=false
    for index,stage in ipairs(record.stages)do
        local ok,reason,maybeMutated=applyStage(stage,stage.before,stage.after,operationId)
        if not ok then failure=reason;uncertain=maybeMutated==true;break end;applied=index
    end
    if failure then
        local recovered=true
        for index=applied,1,-1 do
            local stage=record.stages[index];local ok=applyStage(stage,stage.after,stage.before,operationId..":rollback")
            if not ok then recovered=false end
        end
        record.status=recovered and not uncertain and"rolledBack"or"recovery";record.reason=failure
        for _,key in ipairs(acquired)do locks[key]=nil end
        return false,record.status,copy(record)
    end
    record.status="committed";for _,key in ipairs(acquired)do locks[key]=nil end
    return true,"committed",copy(record)
end

-- Compensation after a different authoritative domain proves it restored its prior state.
-- Verify every stage is still at this operation's committed state before restoring capacity.
function Transactions.rollback(store,operationId)
    if not authority()then return false,"non-authority"end
    local operations,err=operationStore(store,false);if not operations then return false,err end
    local record=operations.records[operationId]
    if not record then return false,"filter transaction unavailable"end
    if record.status=="rolledBack"then return true,"rolledBack",copy(record)end
    if record.status~="committed"or type(record.stages)~="table"or #record.stages>Transactions.MAX_STAGES then return false,"committed filter transaction required"end
    local acquired={};local seen={};local count=0
    for index,stage in pairs(record.stages)do
        count=count+1
        if type(index)~="number"or index%1~=0 or index<1 or index>Transactions.MAX_STAGES or count>Transactions.MAX_STAGES
            or type(stage)~="table"or not valid(stage.providerId)or not valid(stage.stageId)or not valid(stage.filterId)
            or type(stage.before)~="table"or type(stage.after)~="table"then return false,"malformed committed filter stages"end
        for _,state in ipairs({stage.before,stage.after})do
            if not finite(state.remainingCapacity)or state.remainingCapacity<0 or not finite(state.condition)
                or state.condition<0 or state.condition>1 then return false,"malformed committed filter state"end
        end
    end
    if count<1 or count~=#record.stages then return false,"malformed committed filter stages"end
    for _,stage in ipairs(record.stages)do
        local key=stage.providerId..":"..stage.stageId
        if seen[key]then return false,"duplicate committed filter stage"end;seen[key]=true
        if locks[key]then return false,"filter stage busy"end
        local provider=providers[stage.providerId]
        local _,state
        if provider then _,state=current(provider,stage.stageId)end
        if not state or state.filterId~=nil and state.filterId~=stage.filterId
            or not close(state.remainingCapacity,stage.after.remainingCapacity)or not close(state.condition,stage.after.condition)then
            return false,"committed filter stage changed"
        end
        acquired[#acquired+1]=key
    end
    for _,key in ipairs(acquired)do locks[key]=operationId end
    record.status="rollingBack"
    for index=#record.stages,1,-1 do
        local stage=record.stages[index]
        local ok,reason=applyStage(stage,stage.after,stage.before,operationId..":rollback")
        if not ok then
            record.status="recovery";record.reason=reason
            for _,key in ipairs(acquired)do locks[key]=nil end
            return false,"recovery",copy(record)
        end
    end
    record.status="rolledBack";record.reason=nil
    for _,key in ipairs(acquired)do locks[key]=nil end
    return true,"rolledBack",copy(record)
end

function Transactions.cancel(store,operationId)
    if not authority()then return false,"non-authority"end
    local operations,err=operationStore(store,false);if not operations then return false,err end
    local record=operations.records[operationId];if not record then return false,"filter transaction unavailable"end
    if record.status=="cancelled"then return true,"cancelled",copy(record)end
    if record.status~="reserved"then return false,record.status,copy(record)end
    record.status="cancelled";return true,"cancelled",copy(record)
end
function Transactions.inspect(store,operationId)local operations,err=operationStore(store,false);if not operations then return nil,err end
    return operations.records[operationId]and copy(operations.records[operationId])or nil
end
function Transactions.resolveRecovery(store,operationId,mode)
    if not authority()then return false,"non-authority"end
    local operations,err=operationStore(store,false);if not operations then return false,err end
    local record=operations.records[operationId];if not record or record.status~="recovery"then
        return false,"filter recovery unavailable"
    end
    if mode=="accept-committed"then
        for _,stage in ipairs(record.stages)do
            local provider=providers[stage.providerId];if not provider then return false,"filter media provider unavailable"end
            local _,state,stateErr=current(provider,stage.stageId)
            if not state then return false,stateErr end
            if not close(state.remainingCapacity,stage.after.remainingCapacity)or not close(state.condition,stage.after.condition)then
                return false,"filter stage does not match committed state"
            end
        end
        record.status="committed";record.resolution=mode;record.reason=nil
        return true,"committed",copy(record)
    end
    if mode~="restore-before"then return false,"invalid filter recovery resolution"end
    for _,stage in ipairs(record.stages)do
        local provider=providers[stage.providerId];if not provider then return false,"filter media provider unavailable"end
        local _,state,stateErr=current(provider,stage.stageId);if not state then return false,stateErr end
        if not(close(state.remainingCapacity,stage.before.remainingCapacity)and close(state.condition,stage.before.condition))then
            local restored=applyStage(stage,state,stage.before,operationId..":recovery")
            if not restored then return false,"filter recovery restore failed"end
        end
    end
    record.status="rolledBack";record.resolution=mode;record.reason=nil
    return true,"rolledBack",copy(record)
end

waterWorks.FilterTransactions=Transactions
waterWorks.registerFilterMediaProvider=Transactions.registerProvider
waterWorks.reserveFilterTransaction=Transactions.reserve
waterWorks.commitFilterTransaction=Transactions.commit
waterWorks.cancelFilterTransaction=Transactions.cancel
waterWorks.rollbackFilterTransaction=Transactions.rollback
waterWorks.resolveFilterRecovery=Transactions.resolveRecovery
return Transactions
