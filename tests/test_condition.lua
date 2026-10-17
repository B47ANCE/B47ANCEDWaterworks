isClient=function()return false end
local api=dofile(arg[1]); dofile(arg[2]); local registry=dofile(arg[3]); local condition=dofile(arg[4])
registry.registerProvider({id="condition.tank",matches=function(o)return o.tank end,describe=function(o)return {networkId="condition",stableKey="tank",kind="storage",channel="WATER",x=0,y=0,z=0}end})
local fluid={amount=10,capacity=10,getAmount=function(s)return s.amount end,getCapacity=function(s)return s.capacity end,isTaintedWater=function()return false end,adjustAmount=function(s,v)s.amount=v end}
local object={tank=true,md={},getFluidContainer=function()return fluid end,getModData=function(s)return s.md end,sync=function()end}
local store=registry.newStore();assert(registry.attachStore(store));local _,attached=registry.attachObject(store,object)
assert(condition.set(store,attached.nodeId,{condition=.8,leakRatePerHour=1,lastProcessedHour=10}))
local ok,result=condition.step(store,11,1);assert(ok and result.leaked==1 and fluid.amount==9)
local state=condition.inspect(store,attached.nodeId);assert(state.leakedTotal==1 and state.lastProcessedHour==11)
assert(condition.damage(store,attached.nodeId,.3,.5,"impact"));state=condition.inspect(store,attached.nodeId);assert(state.condition==.5 and state.leakRatePerHour==1.5)
assert(condition.repair(store,attached.nodeId,.2,1));state=condition.inspect(store,attached.nodeId);assert(state.condition==.7 and state.leakRatePerHour==.5)
registry.detachObject(store,object);condition.step(store,12,1);state=condition.inspect(store,attached.nodeId);assert(state.lastError=="node not loaded" and fluid.amount==9)
isClient=function()return true end;assert(condition.damage(store,attached.nodeId,.1,0)==false)
print("B47ANCEDWaterworks bounded infrastructure leak/condition checks passed")
next=nil -- Build 42 Kahlua release compatibility.
