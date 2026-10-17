local waterWorks=rawget(_G,"waterWorks") or require "waterWorks/API"
local Iteration=require "waterWorks/Iteration"
local Flow=waterWorks.Flow or require "waterWorks/Flow"
local Scheduler={SCHEMA_VERSION=1,MAX_SCHEDULES=1024,MAX_ID=96,DEFAULT_BUDGET=4}
local cursors=setmetatable({},{__mode="k"})

local function authoritative() return not (type(isClient)=="function" and isClient()==true) end
local function finite(v) return type(v)=="number" and v==v and v~=math.huge and v~=-math.huge end
local function validId(v,max) return type(v)=="string" and v~="" and #v<=(max or Scheduler.MAX_ID) and not v:find("[%c]",1) end
local function schedules(store)
    if type(store)~="table" then return nil,"registry store required" end
    if store.scheduledDemands==nil then store.scheduledDemands={schemaVersion=Scheduler.SCHEMA_VERSION,revision=0,entries={}} end
    local value=store.scheduledDemands
    if type(value)~="table" or value.schemaVersion~=Scheduler.SCHEMA_VERSION or type(value.entries)~="table" then
        return nil,"unsupported demand schedule schema"
    end
    return value
end
local function count(entries)local n=0; for _ in pairs(entries)do n=n+1 end; return n end

function Scheduler.schedule(store,definition)
    if not authoritative() then return false,"non-authority" end
    if type(definition)~="table" or not validId(definition.id) or not validId(definition.sourceId,128)
        or not validId(definition.targetId,128) then return false,"valid demand definition required" end
    local amount,interval,nextRun=tonumber(definition.amount),tonumber(definition.intervalHours),tonumber(definition.nextRunHour)
    if not finite(amount) or amount<=0 or amount>100 or not finite(interval) or interval<=0
        or not finite(nextRun) or nextRun<0 then return false,"invalid demand timing or amount" end
    local state,err=schedules(store); if not state then return false,err end
    if not state.entries[definition.id] and count(state.entries)>=Scheduler.MAX_SCHEDULES then return false,"demand schedule limit reached" end
    local previous=state.entries[definition.id]
    state.entries[definition.id]={id=definition.id,sourceId=definition.sourceId,targetId=definition.targetId,
        amount=amount,intervalHours=interval,nextRunHour=nextRun,minimumPressure=math.max(0,tonumber(definition.minimumPressure) or 0),
        enabled=definition.enabled~=false,runCount=previous and(tonumber(previous.runCount)or 0)or 0,
        failureCount=previous and(tonumber(previous.failureCount)or 0)or 0,
        lastRunHour=previous and previous.lastRunHour or nil,lastError=previous and previous.lastError or nil}
    state.revision=state.revision+1; return true,state.entries[definition.id]
end
function Scheduler.cancel(store,id)
    if not authoritative() then return false,"non-authority" end
    local state,err=schedules(store); if not state then return false,err end
    if not validId(id) or not state.entries[id] then return false,"unknown demand schedule" end
    state.entries[id]=nil; state.revision=state.revision+1; return true
end
function Scheduler.step(store,worldHour,budget)
    if not authoritative() then return false,"non-authority" end
    worldHour=tonumber(worldHour); budget=math.max(0,math.floor(tonumber(budget) or Scheduler.DEFAULT_BUDGET))
    if not finite(worldHour) or worldHour<0 then return false,"invalid world time" end
    local state,err=schedules(store); if not state then return false,err end
    local cursor=cursors[store]; local inspected,executed,succeeded=0,0,0
    while inspected<budget do
        local id,entry=Iteration.nextEntry(state.entries,cursor)
        if not id then cursor=nil;break end
        cursor=id; inspected=inspected+1
        if entry.enabled and worldHour>=entry.nextRunHour then
            executed=executed+1
            local ok,result=Flow.transfer(store,entry.sourceId,entry.targetId,entry.amount,
                {operationId="waterWorks.demand:"..entry.id..":"..tostring(entry.runCount+entry.failureCount+1),minimumPressure=entry.minimumPressure})
            entry.lastRunHour=worldHour; entry.nextRunHour=worldHour+entry.intervalHours
            if ok then entry.runCount=entry.runCount+1; entry.lastError=nil; succeeded=succeeded+1
            else entry.failureCount=entry.failureCount+1; entry.lastError=tostring(result or "flow failed") end
            state.revision=state.revision+1
        end
        if Iteration.nextEntry(state.entries,cursor)==nil then cursor=nil; break end
    end
    cursors[store]=cursor
    return true,{inspected=inspected,executed=executed,succeeded=succeeded,revision=state.revision,cursor=cursor}
end
function Scheduler.inspect(store)
    local state,err=schedules(store); if not state then return nil,err end
    local entries={}; for id,value in pairs(state.entries) do local copy={}; for k,v in pairs(value)do copy[k]=v end; entries[id]=copy end
    return {schemaVersion=state.schemaVersion,revision=state.revision,count=count(entries),entries=entries}
end

waterWorks.DemandScheduler=Scheduler
waterWorks.scheduleDemand=Scheduler.schedule
waterWorks.cancelDemand=Scheduler.cancel
return Scheduler
