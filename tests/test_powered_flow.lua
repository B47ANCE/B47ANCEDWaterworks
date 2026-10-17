isClient=function() return false end
local power=dofile(arg[1])
power.registerBattery({item="Test.PumpCell",size="PACK",capacity=10})
power.registerConsumer({item="Test.PumpMotor",sizes={"PACK"},storageMode="modData",referenceCapacity=10})
FluidContainer={CanTransfer=function()return true end,Transfer=function(a,b,n)a.amount=a.amount-n;b.amount=b.amount+n end}
local api=dofile(arg[2]); local network=dofile(arg[3]); local registry=dofile(arg[4]); local infrastructure=dofile(arg[5])
local hydraulics=dofile(arg[6]); local pumpPower=dofile(arg[7]); local flow=dofile(arg[8])
local function fluidObject(key,kind,x,amount)
    local fluid={amount=amount,capacity=10,isTaintedWater=function()return false end}
    function fluid:getAmount()return self.amount end; function fluid:getCapacity()return self.capacity end
    local object={key=key,kind=kind,x=x,state={},data={}}
    function object:getFluidContainer()return fluid end; function object:getModData()return self.data end; function object:sync()end
    return object
end
for _,kind in ipairs({"source","storage"}) do local role=kind; infrastructure.registerProvider({id="powered."..role,kind=role,
    matches=function(o)return o.kind==role end,describe=function(o)return {networkId="system",stableKey=o.key,channel="WATER",x=o.x,y=0,z=0} end,
    getState=function(o)return {amount=o:getFluidContainer():getAmount(),capacity=10,supply=10,pressure=20} end}) end
pumpPower.registerProvider({id="powered.pump",matches=function(o)return o.kind=="pump" end,
    describe=function(o)return {networkId="system",stableKey=o.key,channel="WATER",x=o.x,y=0,z=0} end,
    getConsumer=function(o)return o.consumer end,energyPerFluidUnit=1,getState=function()return {pressure=30} end})
local consumer={data={}}
function consumer:getFullType()return "Test.PumpMotor" end; function consumer:getModData()return self.data end
assert(power.initializeEmbeddedBattery(consumer,"Test.PumpCell",1))
local function charge()local ok,value=power.readConsumerCharge(consumer);assert(ok);return value end
local source=fluidObject("source","source",0,6); local pump={key="pump",kind="pump",x=1,consumer=consumer}; local target=fluidObject("target","storage",2,0)
local loaded={source,pump,target}; local store=registry.newStore(); assert(registry.attachStore(store)); local ids={}
for _,object in ipairs(loaded) do local ok,result=registry.attachObject(store,object); assert(ok); ids[#ids+1]=result.nodeId end
local graph=store.networks.system; assert(network.connect(graph,ids[1],ids[2])); assert(network.connect(graph,ids[2],ids[3]))
while not network.stepTopology(graph,8).complete do end; while not hydraulics.step(store,"system",8).complete do end
local ok,result=flow.transfer(store,ids[1],ids[3],2,{operationId="powered-flow"})
assert(ok and result.amount==2 and math.abs(charge()-.8)<.0001)
FluidContainer.CanTransfer=function()return false end
local before=charge()
local failed,reason=flow.transfer(store,ids[1],ids[3],1,{operationId="failed-powered-flow"})
assert(not failed and reason:find("energy rollback verified",1,true))
assert(charge()==before and power.inspectEnergyRecovery(consumer)==nil)
print("B47ANCEDWaterworks cross-domain pump energy/fluid transaction checks passed")

local chargedBefore=charge();local sourceBefore=source:getFluidContainer():getAmount()
local targetBefore=target:getFluidContainer():getAmount()
isClient=function()return true end
local denied,denial=flow.transfer(store,ids[1],ids[3],1,{operationId="client-denied-flow"})
assert(not denied and denial=="non-authority" and charge()==chargedBefore)
assert(source:getFluidContainer():getAmount()==sourceBefore and target:getFluidContainer():getAmount()==targetBefore)
isClient=function()return false end
B47ANCEDPower=nil
local absent,absence=flow.transfer(store,ids[1],ids[3],1,{operationId="missing-power-flow"})
assert(not absent and absence=="no open loaded path" and charge()==chargedBefore)
assert(source:getFluidContainer():getAmount()==sourceBefore and target:getFluidContainer():getAmount()==targetBefore)
