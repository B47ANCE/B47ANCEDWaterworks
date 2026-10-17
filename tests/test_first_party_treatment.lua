isClient=function()return false end
local power=dofile(arg[1])
power.registerBattery({item="B47ANCEDPower.BatteryLithiumPack",size="PACK",capacity=15})
local network=dofile(arg[2]);local registry=dofile(arg[3]);dofile(arg[4]);dofile(arg[5]);local treatment=dofile(arg[6])
assert(power.getConsumerProfile(treatment.PURIFIER_TYPE).sizes[1]=="PACK")
local item={md={},condition=75}
function item:getFullType()return treatment.PURIFIER_TYPE end
function item:getModData()return self.md end
function item:getCondition()return self.condition end
function item:getConditionMax()return 100 end
local world={md={waterWorksNetworkId="clean-water"},item=item}
function world:getItem()return self.item end;function world:getModData()return self.md end
function world:getX()return 4 end;function world:getY()return 8 end;function world:getZ()return 0 end
function world:getObjectIndex()return 2 end
local store=registry.newStore();assert(registry.attachStore(store));local ok,result=registry.attachObject(store,world);assert(ok)
local state=assert(waterWorks.inspectInfrastructureNode(store,result.nodeId))
assert(state.kind=="treatment"and state.treatmentId=="boiled"and state.available
    and state.energyCost==.25 and state.energyPerFluidUnit==.08
    and state.heatDeltaC==5 and state.maxHeatDeltaC==20 and state.energyPerDegreeC==.1)
item.condition=0;state=assert(waterWorks.inspectInfrastructureNode(store,result.nodeId))
assert(state.available==false,"destroyed purifier must fail closed")
print("B47ANCEDWaterworks first-party electric purifier provider checks passed")
