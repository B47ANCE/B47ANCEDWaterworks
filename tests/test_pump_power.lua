isClient=function() return false end
local api=dofile(arg[1]); local network=dofile(arg[2]); local registry=dofile(arg[3]); local infrastructure=dofile(arg[4])
local pumpPower=dofile(arg[5])
powerWorks={getConsumerPowerState=function(consumer)return {known=true,powered=consumer.charged} end}
pumpPower.registerProvider({id="test.poweredPump",matches=function(o)return o.pump end,
    describe=function(o)return {networkId="well",stableKey=o.key,channel="WATER",x=0,y=0,z=0} end,
    getConsumer=function(o)return o.consumer end,energyPerFluidUnit=.25,getState=function()return {pressure=30,powerDemand=2} end})
local store=registry.newStore(); assert(registry.attachStore(store)); local pump={pump=true,key="pump",consumer={charged=true}}
local ok,result=registry.attachObject(store,pump); assert(ok)
local state=assert(infrastructure.inspectNode(store,result.nodeId)); assert(state.kind=="pump" and state.powered and state.pressure==30 and state.energyPerFluidUnit==.25)
pump.consumer.charged=false; local depleted=assert(infrastructure.inspectNode(store,result.nodeId)); assert(depleted.powered==false,"powered="..tostring(depleted.powered).." fault="..tostring(depleted.fault))
B47ANCEDPower={getConsumerPowerState=function()return {known=true,powered=false}end}
pump.consumer.charged=true
assert(infrastructure.inspectNode(store,result.nodeId).powered==false,"canonical Power must take precedence over a legacy global")
B47ANCEDPower.getConsumerPowerState=function()return {known=false,powered=false}end
local unknown=assert(infrastructure.inspectNode(store,result.nodeId))
assert(not unknown.powered and unknown.fault=="power state unavailable","unknown current Power must not fall back to stale legacy power")
B47ANCEDPower=nil
assert(infrastructure.inspectNode(store,result.nodeId).powered==true,"legacy Power remains supported")
powerWorks=nil; local unavailable=assert(infrastructure.inspectNode(store,result.nodeId)); assert(not unavailable.powered and unavailable.fault~="")
print("B47ANCEDWaterworks optional powerWorks pump-state integration checks passed")

B47ANCEDPower={getConsumerPowerState=function()return {known=true,powered=true}end}
assert(infrastructure.inspectNode(store,result.nodeId).powered==true,"Power state lookup must discover later availability without cached absence")
