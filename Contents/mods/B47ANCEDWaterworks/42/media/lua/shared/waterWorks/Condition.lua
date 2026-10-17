local waterWorks=rawget(_G,"waterWorks") or require "waterWorks/API"
local Iteration=require "waterWorks/Iteration"
local Registry=waterWorks.Registry or require "waterWorks/Registry"
local Condition={SCHEMA_VERSION=1,MAX_ENTRIES=65536,DEFAULT_BUDGET=8,MAX_ELAPSED_HOURS=24}
local cursors=setmetatable({},{__mode="k"})
local transactionLocks={}
local function authoritative()return not(type(isClient)=="function" and isClient()==true)end
local function finite(v)return type(v)=="number" and v==v and v~=math.huge and v~=-math.huge end
local function clamp(v)return math.max(0,math.min(1,tonumber(v)or 0))end
local function state(store)
    if type(store)~="table" or type(store.nodeIndex)~="table" then return nil,"registry store required" end
    if store.infrastructureCondition==nil then store.infrastructureCondition={schemaVersion=1,revision=0,entries={}} end
    local value=store.infrastructureCondition
    if type(value)~="table" or value.schemaVersion~=Condition.SCHEMA_VERSION or type(value.entries)~="table" then return nil,"unsupported condition schema" end
    return value
end
local function count(t)local n=0;for _ in pairs(t)do n=n+1 end;return n end
local function copy(t)local r={};for k,v in pairs(t or{})do r[k]=v end;return r end
function Condition.set(store,nodeId,definition)
    if not authoritative()then return false,"non-authority"end
    local s,err=state(store);if not s then return false,err end
    if not store.nodeIndex[nodeId]then return false,"unknown node"end
    definition=type(definition)=="table"and definition or{}
    local condition=tonumber(definition.condition);local leak=tonumber(definition.leakRatePerHour)
    if not finite(condition)or condition<0 or condition>1 or not finite(leak)or leak<0 or leak>100 then return false,"invalid condition state"end
    if not s.entries[nodeId]and count(s.entries)>=Condition.MAX_ENTRIES then return false,"condition limit reached"end
    s.entries[nodeId]={nodeId=nodeId,condition=condition,leakRatePerHour=leak,lastProcessedHour=tonumber(definition.lastProcessedHour),
        leakedTotal=math.max(0,tonumber(definition.leakedTotal)or 0),failureCount=0,lastError=nil,cause=tostring(definition.cause or "")}
    s.revision=s.revision+1;return true,s.entries[nodeId]
end
function Condition.damage(store,nodeId,amount,leakIncrease,cause)
    if not authoritative()then return false,"non-authority"end
    local s,err=state(store);if not s then return false,err end
    local entry=s.entries[nodeId];if not entry then return false,"condition state unavailable"end
    amount,leakIncrease=tonumber(amount),tonumber(leakIncrease)or 0
    if not finite(amount)or amount<=0 or not finite(leakIncrease)or leakIncrease<0 then return false,"invalid damage"end
    entry.condition=clamp(entry.condition-amount);entry.leakRatePerHour=math.min(100,entry.leakRatePerHour+leakIncrease);entry.cause=tostring(cause or entry.cause)
    s.revision=s.revision+1;return true,entry
end
function Condition.repair(store,nodeId,conditionGain,leakReduction)
    if not authoritative()then return false,"non-authority"end
    local s,err=state(store);if not s then return false,err end
    local entry=s.entries[nodeId];if not entry then return false,"condition state unavailable"end
    conditionGain,leakReduction=tonumber(conditionGain),tonumber(leakReduction)
    if not finite(conditionGain)or conditionGain<=0 or not finite(leakReduction)or leakReduction<0 then return false,"invalid repair"end
    entry.condition=clamp(entry.condition+conditionGain);entry.leakRatePerHour=math.max(0,entry.leakRatePerHour-leakReduction)
    if entry.leakRatePerHour==0 then entry.lastError=nil end
    s.revision=s.revision+1;return true,entry
end
function Condition.repairTransaction(store,nodeId,conditionGain,leakReduction,commit)
    if not authoritative()then return false,"non-authority"end
    if type(commit)~="function"then return false,"repair commit callback required"end
    if transactionLocks[nodeId]then return false,"condition repair busy"end
    local s,err=state(store);if not s then return false,err end
    local prior=s.entries[nodeId];if not prior then return false,"condition state unavailable"end
    local snapshot=copy(prior);transactionLocks[nodeId]=true
    local repaired,result=Condition.repair(store,nodeId,conditionGain,leakReduction)
    if not repaired then transactionLocks[nodeId]=nil;return false,result end
    local called,outcome,reason=pcall(commit,copy(result))
    if called and outcome==true then transactionLocks[nodeId]=nil;return true,copy(result)end
    if called and outcome==nil then
        transactionLocks[nodeId]=nil
        return false,reason or"repair committed; resource outcome uncertain",{committed=true,uncertain=true,state=copy(result)}
    end
    s.entries[nodeId]=snapshot;s.revision=s.revision+1;transactionLocks[nodeId]=nil
    return false,(called and reason or outcome)or"repair resource commit failed",{committed=false,rolledBack=true,state=copy(snapshot)}
end
function Condition.resolveRepairRecovery(store,nodeId,record,mode)
    if not authoritative()then return false,"non-authority"end
    if transactionLocks[nodeId]then return false,"condition repair busy"end
    if type(record)~="table"or record.requiresInspection~=true then return false,"repair recovery record required"end
    if mode~="acceptCommitted"and mode~="restoreCondition"then return false,"unsupported repair recovery resolution"end
    local s,err=state(store);if not s then return false,err end
    local entry=s.entries[nodeId];if not entry then return false,"condition state unavailable"end
    local afterCondition,afterLeak=tonumber(record.conditionAfter),tonumber(record.leakAfter)
    local beforeCondition,beforeLeak=tonumber(record.conditionBefore),tonumber(record.leakBefore)
    if not finite(afterCondition)or not finite(afterLeak)or not finite(beforeCondition)or not finite(beforeLeak)
        or afterCondition<0 or afterCondition>1 or beforeCondition<0 or beforeCondition>1
        or afterLeak<0 or afterLeak>100 or beforeLeak<0 or beforeLeak>100 then return false,"invalid repair recovery state"end
    if math.abs(entry.condition-afterCondition)>.000001 or math.abs(entry.leakRatePerHour-afterLeak)>.000001 then
        return false,"condition changed since uncertain repair"
    end
    if mode=="restoreCondition"then
        entry.condition=beforeCondition;entry.leakRatePerHour=beforeLeak;s.revision=s.revision+1
    end
    return true,copy(entry)
end
function Condition.step(store,worldHour,budget)
    if not authoritative()then return false,"non-authority"end
    worldHour=tonumber(worldHour);budget=math.max(0,math.floor(tonumber(budget)or Condition.DEFAULT_BUDGET))
    if not finite(worldHour)or worldHour<0 then return false,"invalid world time"end
    local s,err=state(store);if not s then return false,err end
    local cursor=cursors[store];local inspected,attempted,leaked=0,0,0
    while inspected<budget do
        local id,entry=Iteration.nextEntry(s.entries,cursor);if not id then cursor=nil;break end
        cursor=id;inspected=inspected+1
        local prior=tonumber(entry.lastProcessedHour);entry.lastProcessedHour=worldHour
        local elapsed=prior and math.max(0,math.min(Condition.MAX_ELAPSED_HOURS,worldHour-prior))or 0
        if elapsed>0 and entry.leakRatePerHour>0 then
            local object=Registry.getRuntimeObject(store,id)
            if object then
                attempted=attempted+1;local ok,result=waterWorks.drain(object,entry.leakRatePerHour*elapsed,{operationId="waterWorks.leak:"..id..":"..tostring(worldHour)})
                if ok then entry.leakedTotal=entry.leakedTotal+result.amount;entry.lastError=nil;leaked=leaked+result.amount
                else entry.failureCount=entry.failureCount+1;entry.lastError=tostring(result)end
            else entry.lastError="node not loaded"end
        end
        s.revision=s.revision+1
        if Iteration.nextEntry(s.entries,cursor)==nil then cursor=nil;break end
    end
    cursors[store]=cursor;return true,{inspected=inspected,attempted=attempted,leaked=leaked,revision=s.revision,cursor=cursor}
end
function Condition.inspect(store,nodeId)
    local s,err=state(store);if not s then return nil,err end
    local entry=s.entries[nodeId];if not entry then return nil,"condition state unavailable"end
    local copy={};for k,v in pairs(entry)do copy[k]=v end;return copy
end
waterWorks.Condition=Condition;waterWorks.setInfrastructureCondition=Condition.set
waterWorks.damageInfrastructure=Condition.damage;waterWorks.repairInfrastructure=Condition.repair
waterWorks.repairInfrastructureTransaction=Condition.repairTransaction
return Condition
