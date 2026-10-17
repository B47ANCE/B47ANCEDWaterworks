isClient=function() return false end
local api=dofile(arg[1]); local network=dofile(arg[2]); local registry=dofile(arg[3])
local infrastructure=dofile(arg[4]); local hydraulics=dofile(arg[5])
infrastructure.registerProvider({id="test.hydraulic",kind="junction",
    matches=function(o)return o.hydraulic end,
    describe=function(o)return {networkId="system",stableKey=o.key,kind=o.kind,channel="WATER",x=o.x,y=0,z=0} end,
    getState=function(o)return o.state end})
-- Register separate typed contracts because provider kind is intentionally immutable.
for _,kind in ipairs({"source","storage","fixture","pump","valve"}) do
    local role=kind
    infrastructure.registerProvider({id="test."..role,kind=role,priority=10,
        matches=function(o)return o.kind==role end,
        describe=function(o)return {networkId="system",stableKey=o.key,channel="WATER",x=o.x,y=0,z=0} end,
        getState=function(o)return o.state end})
end
local store=registry.newStore(); assert(registry.attachStore(store))
local ids={}
local definitions={
    {key="source",kind="source",x=0,state={supply=20,pressure=40}},
    {key="tank",kind="storage",x=1,state={amount=10,capacity=50}},
    {key="tap",kind="fixture",x=2,state={demand=15}},
    {key="pump",kind="pump",x=3,state={powered=true,pressure=60,powerDemand=2}},
}
for _,object in ipairs(definitions) do local ok,result=registry.attachObject(store,object); assert(ok); ids[#ids+1]=result.nodeId end
local graph=store.networks.system
for index=1,#ids-1 do assert(network.connect(graph,ids[index],ids[index+1])) end
while not network.stepTopology(graph,2).complete do end
local stepCount=0
repeat local result=assert(hydraulics.step(store,"system",1)); assert(result.work<=1); stepCount=stepCount+1 until result.complete
assert(stepCount>1)
local report=assert(hydraulics.getReport(store,"system")); local summary=report.components[1]
assert(summary.supply==20 and summary.storedAmount==10 and summary.demand==15)
assert(summary.supplyRatio==1 and summary.estimatedPressure==60 and summary.reliable)
assert(network.disconnect(graph,ids[2],ids[3])); assert(hydraulics.getReport(store,"system")==nil)
assert(hydraulics.step(store,"system",1)==nil,"dirty topology must block hydraulic publication")
print("B47ANCEDWaterworks bounded hydraulic planning checks passed")
next=nil -- Build 42 Kahlua release compatibility.
