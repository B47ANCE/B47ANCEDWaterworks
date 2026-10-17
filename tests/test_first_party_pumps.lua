isClient=function() return false end
local power=dofile(arg[1])
power.registerBattery({item="B47ANCEDPower.BatteryLithiumPack",size="PACK",capacity=15})
local network=dofile(arg[2]); local registry=dofile(arg[3]); dofile(arg[4]); dofile(arg[5]); local pumps=dofile(arg[6])
assert(power.getConsumerProfile(pumps.PORTABLE_TYPE).sizes[1]=="PACK")
local item={md={}}
function item:getFullType() return pumps.PORTABLE_TYPE end
function item:getModData() return self.md end
function item:getUseDelta() return self.delta or 0 end
function item:setUseDelta(v) self.delta=v end
function item:getCondition() return self.condition or 50 end
function item:getConditionMax() return 100 end
local world={md={waterWorksNetworkId="test-water"},item=item}
function world:getItem() return self.item end
function world:getModData() return self.md end
function world:getX() return 10 end; function world:getY() return 20 end; function world:getZ() return 0 end
function world:getObjectIndex() return 3 end
local store=registry.newStore(); assert(registry.attachStore(store)); local ok,result=registry.attachObject(store,world); assert(ok)
assert(result.networkId=="test-water" and result.nodeId=="waterWorks.portablePump:10:20:0:3")
local state=assert(waterWorks.inspectInfrastructureNode(store,result.nodeId))
assert(state.kind=="pump" and state.powered==false and state.pressure==17.5 and state.flowLimit==3.5
    and state.condition==50 and state.energyPerFluidUnit==0.065,
    string.format("unexpected pump state kind=%s powered=%s pressure=%s flow=%s condition=%s energy=%s",
        tostring(state.kind),tostring(state.powered),tostring(state.pressure),tostring(state.flowLimit),
        tostring(state.condition),tostring(state.energyPerFluidUnit)))
assert(power.initializeEmbeddedBattery(item,"B47ANCEDPower.BatteryLithiumPack",1/3))
state=assert(waterWorks.inspectInfrastructureNode(store,result.nodeId)); assert(state.powered==true)
local consumer=assert(waterWorks.PumpPower.getConsumer(store,result.nodeId)); assert(consumer==item)
item.condition=0;state=assert(waterWorks.inspectInfrastructureNode(store,result.nodeId))
assert(state.available==false and state.flowLimit==1,"destroyed pump must not provide flow")
print("B47ANCEDWaterworks first-party placed portable-pump checks passed")
