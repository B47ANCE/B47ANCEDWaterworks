isClient=function()return false end
waterWorks={Flow={calls={},transfer=function(selfStore,source,target,amount,options)local calls=waterWorks.Flow.calls; calls[#calls+1]={source,target,amount,options}; if source=="bad" then return false,"blocked" end; return true,{amount=amount} end}}
local scheduler=dofile(arg[1]); local store={}
assert(scheduler.schedule(store,{id="daily",sourceId="source",targetId="target",amount=2,intervalHours=24,nextRunHour=10}))
assert(scheduler.schedule(store,{id="failure",sourceId="bad",targetId="target",amount=1,intervalHours=2,nextRunHour=10}))
local ok,first=scheduler.step(store,9,1); assert(ok and first.inspected==1 and first.executed==0)
local totalExecuted,totalSuccess=0,0
for _=1,2 do local _,result=scheduler.step(store,10,1); totalExecuted=totalExecuted+result.executed; totalSuccess=totalSuccess+result.succeeded end
assert(totalExecuted==2 and totalSuccess==1 and #waterWorks.Flow.calls==2)
local report=scheduler.inspect(store); assert(report.count==2 and report.entries.daily.runCount==1 and report.entries.failure.failureCount==1)
assert(report.entries.daily.nextRunHour==34 and report.entries.failure.nextRunHour==12)
assert(scheduler.schedule(store,{id="daily",sourceId="source",targetId="target",amount=3,intervalHours=12,nextRunHour=40}))
report=scheduler.inspect(store);assert(report.entries.daily.amount==3 and report.entries.daily.runCount==1
    and report.entries.daily.lastRunHour==10,"schedule updates must retain execution history")
assert(scheduler.cancel(store,"daily") and scheduler.inspect(store).count==1)
isClient=function()return true end; assert(scheduler.schedule(store,{id="client",sourceId="a",targetId="b",amount=1,intervalHours=1,nextRunHour=1})==false)
print("B47ANCEDWaterworks bounded persistent demand-scheduler checks passed")
next=nil -- Build 42 Kahlua release compatibility.
