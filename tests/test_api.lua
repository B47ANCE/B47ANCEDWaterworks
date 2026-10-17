isClient=function() return false end
local function owner(amount,capacity,quality)
    local data={}; local fluid={amount=amount,capacity=capacity}
    function fluid:getAmount() return self.amount end
    function fluid:getCapacity() return self.capacity end
    function fluid:isTaintedWater() return false end
    function fluid:isWaterSource() return true end
    function fluid:isWaterOnlySource() return true end
    function fluid:isMixture() return false end
    function fluid:adjustAmount(value) self.amount=value end
    function fluid:getPrimaryFluid() return {getFluidTypeString=function()return "Water" end} end
    local value={fluid=fluid,data=data,tainted=false}
    function value:getFluidContainer() return self.fluid end
    function value:getModData() return self.data end
    function value:setTaintedWater(v) self.tainted=v end
    function value:sync() self.synced=true end
    if quality then data.waterWorksQuality=quality end
    return value
end
FluidContainer={
    CanTransfer=function(source,target) return source.amount>0 and target.amount<target.capacity end,
    Transfer=function(source,target,amount) source.amount=source.amount-amount; target.amount=target.amount+amount end,
}
local api=dofile(arg[1])
assert(api.isFeatureEnabled("ExampleFeature"))
SandboxVars={waterWorks={ExampleFeature=false}}
assert(not api.isFeatureEnabled("ExampleFeature")and api.isFeatureEnabled("OtherFeature"),"sandbox feature helper must default on and honor explicit false")
SandboxVars=nil
local source=owner(5,5,{biological=0.8,particulate=0.4,treatment="untreated"})
local target=owner(5,10,{biological=0,particulate=0,treatment="boiled"})
local ok,result=api.transfer(source,target,2)
assert(ok and result.amount==2 and source.fluid.amount==3 and target.fluid.amount==7)
assert(type(result.operationId)=="string" and result.operationId~="")
assert(math.abs(result.quality.biological-(1.6/7))<0.0001)
assert(target.tainted==true,"questionable detailed quality must map to vanilla tainted compatibility")
assert(api.deriveQualityState({biological=.9})=="SEVERELY_CONTAMINATED")
local legacy={data={},getModData=function(s)return s.data end,getWaterAmount=function()return 3 end,getWaterMax=function()return 10 end,isTaintedWater=function()return true end}
local adapted=assert(api.getContainer(legacy)); assert(adapted.kind=="legacy-water")
assert(api.getQuality(legacy).biological==0.75)
api.registerQualityProvider({id="test.rain",priority=10,
    matches=function(value)return value.rain==true end,
    getQuality=function()return {biological=.3,particulate=.2,turbidity=.1,treatment="rain"} end})
local rain=owner(2,5); rain.rain=true
local rainQuality=api.getQuality(rain)
assert(rainQuality.providerId=="test.rain" and rainQuality.biological==.3)
local boiledOk,boiled=api.applyTreatment(rain,"boiled",{worldAgeHours=10})
assert(boiledOk and boiled.biological==.02 and boiled.particulate==.2)
assert(rain.data.waterWorksTreatmentHistory[1].id=="boiled")
assert(api.applyTreatment(rain,"missing") == false)
local rollbackTreatment=owner(2,5,{biological=.7,chemical=.3,treatment="untreated"})
rollbackTreatment.data.waterWorksTreatmentHistory={{id="prior",worldAgeHours=1}}
local canonicalSetQuality=api.setQuality; local writes=0
api.setQuality=function(subject,quality)
    writes=writes+1
    if writes==1 then return true,api.normalizeQuality(quality) end
    return canonicalSetQuality(subject,quality)
end
local treated,treatmentReason=api.applyTreatment(rollbackTreatment,"boiled",{operationId="treatment-rollback"})
assert(not treated and treatmentReason=="treatment quality readback mismatch")
assert(api.getQuality(rollbackTreatment).biological==.7 and rollbackTreatment.data.waterWorksTreatmentHistory[1].id=="prior")
assert(api.inspectTreatmentRecovery(rollbackTreatment)==nil,"verified treatment rollback must clear recovery")
api.setQuality=canonicalSetQuality
local inspection=assert(api.inspectContainer(rain))
assert(inspection.kind=="fluid-container" and inspection.primaryFluid=="Water")
assert(inspection.capabilities.waterSource and inspection.capabilities.waterOnlySource and not inspection.capabilities.mixture)
assert(inspection.qualityState=="QUESTIONABLE","boiling must not erase particulate risk")
local noState=owner(0,10)
noState.getModData=nil
local sourceBefore=source.fluid.amount
local refused,reason=api.transfer(source,noState,1)
assert(refused==false and reason=="target quality state unavailable")
assert(source.fluid.amount==sourceBefore and noState.fluid.amount==0,"failed quality preflight must not move fluid")
assert(api.transfer(source,target,0/0)==false,"non-finite transfer amount must fail before mutation")
local draining=owner(3,5); local drained,drainResult=api.drain(draining,1,{operationId="drain-1"})
assert(drained and drainResult.amount==1 and draining.fluid.amount==2 and api.inspectDrainRecovery(draining)==nil)
draining.fluid.adjustAmount=function()end
assert(api.drain(draining,1,{operationId="drain-fail"})==false and draining.fluid.amount==2 and api.inspectDrainRecovery(draining)==nil)
local reserved=owner(4,5,{biological=.2})
local reservedOk,reservedResult=api.beginDrainTransaction(reserved,1.5,"appliance-water-1")
assert(reservedOk and not reservedResult.duplicate and reserved.fluid.amount==2.5 and api.inspectDrainRecovery(reserved).status=="reserved")
assert(api.beginDrainTransaction(reserved,1.5,"appliance-water-1"))
assert(api.transfer(reserved,target,.5)==false and api.applyTreatment(reserved,"boiled")==false,"reserved fluid must reject competing mutation")
assert(api.rollbackDrainTransaction(reserved,"appliance-water-1")and reserved.fluid.amount==4 and api.inspectDrainRecovery(reserved)==nil)
assert(api.beginDrainTransaction(reserved,1,"appliance-water-2"))
assert(api.commitDrainTransaction(reserved,"appliance-water-2")and reserved.fluid.amount==3)
assert(api.commitDrainTransaction(reserved,"appliance-water-2"),"drain commit replay must be harmless")

-- A primitive that changes only one side is an uncertain transaction. It must
-- quarantine both containers instead of pretending the requested amount moved.
local badSource=owner(4,4); local badTarget=owner(0,4)
FluidContainer.Transfer=function(src,dst,value) src.amount=src.amount-value end
local badOk,badReason=api.transfer(badSource,badTarget,1,{operationId="asymmetric-1"})
assert(not badOk and badReason:find("recovery inspection required",1,true))
assert(badSource.data[api.TRANSFER_RECOVERY_KEY].operationId=="asymmetric-1")
assert(badTarget.data[api.TRANSFER_RECOVERY_KEY].operationId=="asymmetric-1")
local badReport=api.inspectTransferRecovery(badSource,badTarget)
assert(badReport.requiresInspection and badReport.status=="manual-inspection")
assert(not api.resolveTransferRecovery(badSource,badTarget))
assert(api.transfer(badSource,target,1)==false,"quarantined source must reject new transfers")

-- A persisted interrupted record may be cleared only when both measured
-- amounts prove a complete rollback (or a committed transfer with matching quality).
local recoveredSource=owner(3,4); local recoveredTarget=owner(1,4)
local record={schemaVersion=1,requiresInspection=true,operationId="rollback-1",
    sourceBefore=3,targetBefore=1,sourceAfter=2,targetAfter=2,requested=1,
    targetQualityBefore=api.normalizeQuality({}),reason="simulated interruption"}
recoveredSource.data[api.TRANSFER_RECOVERY_KEY]=record
local targetRecord={}; for k,v in pairs(record) do targetRecord[k]=v end
recoveredTarget.data[api.TRANSFER_RECOVERY_KEY]=targetRecord
local recovery=api.inspectTransferRecovery(recoveredSource,recoveredTarget)
assert(recovery.status=="rolled-back")
assert(api.resolveTransferRecovery(recoveredSource,recoveredTarget))
assert(recoveredSource.data[api.TRANSFER_RECOVERY_KEY]==nil and recoveredTarget.data[api.TRANSFER_RECOVERY_KEY]==nil)
print("B47ANCEDWaterworks B42 adapter/quality/transfer checks passed")

assert(require("B47ANCEDWaterworks/API")==api,"branded import after legacy dofile must reuse existing state")
