isClient=function()return false end
local sent={};sendServerCommand=function(...)sent[#sent+1]={...}end
Events={OnClientCommand={Add=function()end},OnTick={Add=function()end}}
getGameTime=function()return{getWorldAgeHours=function()return 12 end}end
local power=dofile(arg[1])
power.registerBattery({item="Test.Cell",size="PACK",capacity=10}); power.registerConsumer({item="Test.Purifier",sizes={"PACK"},storageMode="modData",referenceCapacity=10})
dofile(arg[2]); local network=dofile(arg[3]); local registry=dofile(arg[4]); local infrastructure=dofile(arg[5]); dofile(arg[6]); local devices=dofile(arg[7])
local consumer={md={},getFullType=function()return "Test.Purifier" end,getModData=function(s)return s.md end}
assert(power.initializeEmbeddedBattery(consumer,"Test.Cell",1))
local function charge()local ok,value=power.readConsumerCharge(consumer);assert(ok);return value end
local device={kind="purifier",key="device",consumer=consumer}
local fluid={amount=5,capacity=10,isTaintedWater=function()return true end,getAmount=function(s)return s.amount end,getCapacity=function(s)return s.capacity end}
local target={kind="tank",key="target",fluid=fluid,md={waterWorksQuality={biological=.8,chemical=.2,treatment="untreated"}}}
function target:getFluidContainer()return self.fluid end; function target:getModData()return self.md end; function target:setTaintedWater(v)self.tainted=v end; function target:sync()end
devices.registerProvider({id="test.purifier",matches=function(o)return o.kind=="purifier" end,
    describe=function(o)return {networkId="treatment",stableKey=o.key,channel="WATER",x=0,y=0,z=0} end,getConsumer=function(o)return o.consumer end,
    getState=function()return {treatmentId="boiled",energyCost=1,enabled=true,available=true,
        heatDeltaC=5,maxHeatDeltaC=20,heatingEnergyCost=.25,energyPerDegreeC=.1} end})
infrastructure.registerProvider({id="test.tank",kind="storage",matches=function(o)return o.kind=="tank" end,
    describe=function(o)return {networkId="treatment",stableKey=o.key,channel="WATER",x=1,y=0,z=0} end,getState=function(o)return {amount=o.fluid.amount,capacity=o.fluid.capacity} end})
local store=registry.newStore(); assert(registry.attachStore(store)); local _,a=registry.attachObject(store,device); local _,b=registry.attachObject(store,target)
assert(network.connect(store.networks.treatment,a.nodeId,b.nodeId)); while not network.stepTopology(store.networks.treatment,4).complete do end
local thermal=dofile(arg[8])
local ok,result=devices.treat(store,a.nodeId,b.nodeId,{operationId="device-treatment-1",worldAgeHours=12})
assert(ok and result.treatmentId=="boiled" and result.energyConsumed==1 and target.md.waterWorksQuality.biological==.02,
    string.format("treatment mismatch ok=%s id=%s energy=%s biological=%s reason=%s",tostring(ok),
        tostring(type(result)=="table"and result.treatmentId),tostring(type(result)=="table"and result.energyConsumed),
        tostring(target.md.waterWorksQuality.biological),tostring(result)))
assert(math.abs(charge()-.9)<.0001)
local prior=charge(); local apply=waterWorks.applyTreatment; waterWorks.applyTreatment=function()return false,"injected failure" end
local failed,reason=devices.treat(store,a.nodeId,b.nodeId,{operationId="device-treatment-2"}); assert(not failed and reason:find("rollback verified",1,true))
assert(math.abs(charge()-prior)<.0001 and power.inspectEnergyRecovery(consumer)==nil)
waterWorks.applyTreatment=apply
local commands=dofile(arg[9]);local server=dofile(arg[10])
local actor={getX=function()return 0 end,getY=function()return 0 end,getZ=function()return 0 end}
local before=charge()
local commandOk,commandResult=server.handle(commands.MODULE,commands.TREAT,actor,
    {requestId="device-command-1",deviceId=a.nodeId,targetId=b.nodeId,treatmentId="boiled"})
assert(commandOk and commandResult.ok and commandResult.proposal.treatmentId=="boiled")
local after=charge();assert(after<before)
local replay=server.handle(commands.MODULE,commands.TREAT,actor,
    {requestId="device-command-1",deviceId=a.nodeId,targetId=b.nodeId,treatmentId="boiled"})
assert(replay==true and charge()==after,"treatment command replay must not charge twice")
assert(thermal.set(store,b.nodeId,{temperatureC=-5,frozen=true}))
local heatBefore=charge()
local heated,heatResult=server.handle(commands.MODULE,commands.HEAT,actor,
    {requestId="device-heat-1",deviceId=a.nodeId,targetId=b.nodeId,deltaC=5})
assert(heated and heatResult.ok and heatResult.proposal.temperatureC==0 and heatResult.proposal.frozen==true)
local heatAfter=charge();assert(heatAfter<heatBefore)
local heatReplay=server.handle(commands.MODULE,commands.HEAT,actor,
    {requestId="device-heat-1",deviceId=a.nodeId,targetId=b.nodeId,deltaC=5})
assert(heatReplay==true and charge()==heatAfter
    and thermal.inspect(store,b.nodeId).temperatureC==0,"heating replay must not charge or heat twice")
print("B47ANCEDWaterworks powered treatment-device transaction checks passed")

local remaining=charge();local biological=target.md.waterWorksQuality.biological
local temperature=thermal.inspect(store,b.nodeId).temperatureC
isClient=function()return true end
local clientTreat,treatReason=devices.treat(store,a.nodeId,b.nodeId,{operationId="client-denied-treatment"})
local clientHeat,heatReason=devices.heat(store,a.nodeId,b.nodeId,{operationId="client-denied-heat",deltaC=5})
assert(not clientTreat and treatReason=="non-authority" and not clientHeat and heatReason=="non-authority")
assert(charge()==remaining and target.md.waterWorksQuality.biological==biological and thermal.inspect(store,b.nodeId).temperatureC==temperature)
isClient=function()return false end
assert(thermal.set(store,b.nodeId,{temperatureC=5,frozen=false}))
temperature=thermal.inspect(store,b.nodeId).temperatureC
B47ANCEDPower=nil
local missingTreat,missingReason=devices.treat(store,a.nodeId,b.nodeId,{operationId="missing-power-treatment"})
local missingHeat,missingHeatReason=devices.heat(store,a.nodeId,b.nodeId,{operationId="missing-power-heat",deltaC=5})
assert(not missingTreat and missingReason=="treatment energy transaction unavailable")
assert(not missingHeat and missingHeatReason=="heating energy transaction unavailable")
assert(charge()==remaining and target.md.waterWorksQuality.biological==biological and thermal.inspect(store,b.nodeId).temperatureC==temperature)
