isClient=function()return false end;waterWorks=nil
package.loaded["waterWorks/API"]=nil;package.loaded["waterWorks/Filters"]=nil
local API=require"waterWorks/API";local Filters=require"waterWorks/Filters"
Filters.register{id="test.sediment",owner="waterWorks",capacity=100,flowRestriction=0,replaceableMedia=true,
    contaminantsRemoved={particulate=true},evaluate=function(quality,amount,state)
        quality.particulate=quality.particulate*.5;return{quality=quality,capacityUsed=amount,flowMultiplier=1}
    end}
local media={a={filterId="test.sediment",remainingCapacity=20,condition=1},b={filterId="test.sediment",remainingCapacity=20,condition=1},
    c={filterId="test.sediment",remainingCapacity=20,condition=1}}
local Transactions=require"waterWorks/FilterTransactions"
Transactions.registerProvider{id="test.media",resolve=function(id)return media[id]end,
    inspect=function(value)return{filterId=value.filterId,remainingCapacity=value.remainingCapacity,condition=value.condition}end,
    apply=function(value,from,to)value.remainingCapacity=to.remainingCapacity;value.condition=to.condition;return true end}
local store={};local request={schemaVersion=1,operationId="filter:1",amount=5,inputQuality={particulate=1},
    stages={{providerId="test.media",stageId="a",filterId="test.sediment"}}}
local ok,status,reserved=Transactions.reserve(store,request);assert(ok and status=="reserved"and reserved.stages[1].after.remainingCapacity==15)
assert(media.a.remainingCapacity==20,"reservation must not mutate physical media")
assert(Transactions.reserve(store,request));request.amount=6;assert(not Transactions.reserve(store,request));request.amount=5
local committed,commitStatus=Transactions.commit(store,"filter:1");assert(committed and commitStatus=="committed"and media.a.remainingCapacity==15)
assert(Transactions.commit(store,"filter:1"),"commit replay must not consume capacity twice")
local cancelRequest={schemaVersion=1,operationId="filter:cancel",amount=1,inputQuality={},stages={{providerId="test.media",stageId="a",filterId="test.sediment"}}}
assert(Transactions.reserve(store,cancelRequest));assert(Transactions.cancel(store,"filter:cancel"));assert(media.a.remainingCapacity==15)
local calls=0;Transactions.registerProvider{id="test.fail",resolve=function(id)return media[id]end,
    inspect=function(value)return{filterId=value.filterId,remainingCapacity=value.remainingCapacity,condition=value.condition}end,
    apply=function(value,from,to)calls=calls+1;if calls==2 then return false end;value.remainingCapacity=to.remainingCapacity;return true end}
local failedRequest={schemaVersion=1,operationId="filter:rollback",amount=2,inputQuality={particulate=1},stages={
    {providerId="test.fail",stageId="a",filterId="test.sediment"},{providerId="test.fail",stageId="b",filterId="test.sediment"}}}
assert(Transactions.reserve(store,failedRequest));local failed,reason=Transactions.commit(store,"filter:rollback")
assert(not failed and reason=="rolledBack"and media.a.remainingCapacity==15 and media.b.remainingCapacity==20,
    "partial physical commit must restore verified earlier media")
local missingStage={schemaVersion=1,operationId="filter:missing",amount=1,inputQuality={},stages={
    {providerId="test.media",stageId="c",filterId="test.sediment"},{providerId="test.media",stageId="missing",filterId="test.sediment"}}}
assert(not Transactions.reserve(store,missingStage));missingStage.operationId="filter:after-missing";missingStage.stages[2]=nil
assert(Transactions.reserve(store,missingStage),"failed multi-stage reservation must release earlier locks")
Transactions.registerProvider{id="test.uncertain",resolve=function(id)return media[id]end,
    inspect=function(value)return{filterId=value.filterId,remainingCapacity=value.remainingCapacity,condition=value.condition}end,
    apply=function(value,from,to)value.remainingCapacity=to.remainingCapacity;return false end}
local uncertain={schemaVersion=1,operationId="filter:uncertain",amount=1,inputQuality={},stages={
    {providerId="test.uncertain",stageId="b",filterId="test.sediment"}}}
assert(Transactions.reserve(store,uncertain));local uncertainOK,uncertainReason=Transactions.commit(store,"filter:uncertain")
assert(not uncertainOK and uncertainReason=="recovery","mutate-then-fail provider must require recovery inspection")
local resolved,resolvedStatus=Transactions.resolveRecovery(store,"filter:uncertain","accept-committed")
assert(resolved and resolvedStatus=="committed"and Transactions.inspect(store,"filter:uncertain").resolution=="accept-committed")
assert(not Transactions.resolveRecovery(store,"filter:uncertain","restore-before"),"resolved records cannot be changed again")
local future={[Transactions.STORE_KEY]={schemaVersion=2,records={},order={}}}
assert(not Transactions.reserve(future,request),"future transaction stores must fail closed without replacement")
isClient=function()return true end;assert(not Transactions.reserve({},request),"client must not own filter capacity")
print("B47ANCEDWaterworks recoverable filter transaction checks passed")
