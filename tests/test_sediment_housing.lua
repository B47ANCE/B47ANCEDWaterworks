local f=dofile("tests/helpers/sediment_fixture.lua")
local H,api,store=f.H,f.api,f.store
local Transactions=require "waterWorks/FilterTransactions"
local Flow=require "waterWorks/Flow"
local ok,claimed=H.claim(store,f.world,f.actor);assert(ok,claimed)
local node=claimed.nodeId;local record=assert(H.recordFor(store,f.world))
assert(record.generation==0 and record.remaining==0 and H.presentation(f.world).hasMedia==false)
local failed=H.replace(store,node,f.actor,"foreign","replace:bad",0)
assert(not failed and f.removed()==0 and record.generation==0)
f.nested.reject=true
assert(not H.replace(store,node,f.actor,tostring(f.cartridge.id),"replace:rejected",0))
assert(record.pending==nil and record.generation==0 and f.removed()==0,"rejected native removal must not refill or consume")
f.nested.reject=false
assert(H.replace(store,node,f.actor,tostring(f.cartridge.id),"replace:one",0))
assert(f.removed()==1 and record.capacity==100 and record.remaining==100 and record.generation==1)
assert(H.replace(store,node,f.actor,tostring(f.cartridge.id),"replace:one",0))
assert(f.removed()==1,"replacement replay must not consume another item")
assert(not H.replace(store,node,f.actor,"21","replace:one",99),"same identity with changed intent must fail")
local graph=store.networks.WATER
assert(f.Network.connect(graph,node,f.targetId))
while not f.Network.stepTopology(graph,8).complete do end
assert(Flow.findOpenPath(store,node,f.targetId)==nil,"ordinary routes must not bypass batch filtration")
assert(H.filter(store,node,f.targetId,f.actor,"filter:one",1))
local quality=api.getQuality(f.target)
assert(quality.particulate==.25 and math.abs(quality.turbidity-.2)<.000001)
assert(quality.biological==.8 and quality.chemical==.4 and quality.salinity==.2 and f.target.tainted==true)
assert(record.remaining==95 and f.fluid.amount==5,"consume measured media capacity without moving fluid")
assert(H.filter(store,node,f.targetId,f.actor,"filter:one",1))
assert(record.remaining==95 and api.getQuality(f.target).particulate==.25,"filtration replay must be inert")
assert(not api.applyTreatment(f.target,H.FILTER_ID,{}),"generic treatment command must not bypass physical media")
assert(Transactions.reserve(store,{schemaVersion=1,operationId="stale:media",amount=1,inputQuality=quality,
    stages={{providerId=H.MEDIA_PROVIDER,stageId=node..":1",filterId=H.FILTER_ID}}}))
SandboxVars={waterWorks={SedimentMediaCapacity=3}}
local replacement=f.media();assert(H.replace(store,node,f.actor,tostring(replacement.id),"replace:two",1))
assert(record.generation==2 and record.remaining==3)
assert(not Transactions.commit(store,"stale:media")and record.remaining==3,"old generation must not charge new media")
assert(not H.filter(store,node,f.targetId,f.actor,"filter:too-large",2)and record.remaining==3,"whole batch must fit")
assert(api.getQuality(f.target).particulate==.25)
SandboxVars.waterWorks.SedimentMediaCapacity=10
replacement=f.media();assert(H.replace(store,node,f.actor,tostring(replacement.id),"replace:three",2))
local apply=api.applyTreatment
api.applyTreatment=function()return false,"injected treatment rejection"end
assert(not H.filter(store,node,f.targetId,f.actor,"filter:rollback",3))
assert(record.remaining==10 and record.pending==nil and api.getQuality(f.target).particulate==.25,
    "proven water rollback must compensate exactly committed media")
api.applyTreatment=apply
assert(f.Registry.detachObject(store,f.world));f.world.x=2
assert(H.claim(store,f.world,f.actor))
assert(record.remaining==10 and record.generation==3 and graph.nodes[node].x==2 and not graph.adjacency[node][f.targetId],
    "explicit relocation must preserve media and remove old edges")
assert(f.Network.connect(graph,node,f.targetId));while not f.Network.stepTopology(graph,8).complete do end
local values=store[H.STORE_KEY];local nextId,identity=values.nextId,f.owned.md
values.nextId=1;f.owned.md={}
assert(not H.claim(store,f.world,f.actor)and values.entries.h1==record and values.nextId==1,
    "corrupt sequence must never overwrite an existing housing ledger entry")
values.nextId=nextId;f.owned.md=identity
SandboxVars.waterWorks.SedimentRemovalFraction=0
assert(not H.filter(store,node,f.targetId,f.actor,"filter:zero",3)and record.remaining==10)
SandboxVars.waterWorks.SedimentRemovalFraction=1
SandboxVars.waterWorks.EnableSedimentFilters=false
assert(not H.filter(store,node,f.targetId,f.actor,"filter:disabled",3)and record.remaining==10)
SandboxVars.waterWorks.EnableSedimentFilters=true
api.applyTreatment=function(owner)
    local q=api.getQuality(owner);q.particulate=.1;assert(api.setQuality(owner,q));return false,"mutate-then-fail"
end
assert(not H.filter(store,node,f.targetId,f.actor,"filter:uncertain",3))
assert(record.remaining==5 and record.pending and H.presentation(f.world).recovery,
    "uncertain water mutation must retain consumed capacity and quarantine")
local last=f.media();local removed=f.removed()
assert(not H.replace(store,node,f.actor,tostring(last.id),"replace:blocked",3)and f.removed()==removed)
api.applyTreatment=apply
local function clone(value)if type(value)~="table"then return value end;local out={};for k,v in pairs(value)do out[k]=clone(v)end;return out end
local saved=clone(store);assert(f.Registry.attachStore(saved));assert(f.Registry.reattachObject(saved,f.world))
local pending=H.recordFor(saved,f.world)
assert(pending.pending and pending.remaining==5 and not H.replace(saved,node,f.actor,tostring(last.id),"replace:restart",3),
    "reload must not reset or refill interrupted state")
local ledger=saved[H.STORE_KEY];ledger.schemaVersion=2
assert(not H.claim(saved,f.world,f.actor)and saved[H.STORE_KEY]==ledger and ledger.schemaVersion==2)
ledger.schemaVersion=1
isClient=function()return true end
assert(not H.claim(saved,f.world,f.actor))
assert(not H.replace(saved,node,f.actor,tostring(last.id),"replace:client",3))
assert(not H.filter(saved,node,f.targetId,f.actor,"filter:client",3))
assert(pending.remaining==5 and f.removed()==removed)
print("sediment housing: capacity, independent axes, replay, replacement generation, rollback, quarantine, save fixture and authority PASS")
