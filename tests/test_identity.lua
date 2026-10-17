-- A branded import must share all live state with existing consumers and saves.
isClient=function()return false end
local branded=require "B47ANCEDWaterworks/API"
local legacy=require "waterWorks/API"
assert(branded==legacy and _G.B47ANCEDWaterworks==legacy and _G.waterWorks==legacy)
assert(branded.MOD_ID=="B47ANCEDWaterworks" and branded.DISPLAY_NAME=="B47ANCE’d Waterworks")
assert(branded.VERSION=="0.35.0")
assert(branded.QUALITY_KEY=="waterWorksQuality" and branded.DRAIN_RECOVERY_KEY=="waterWorksDrainRecovery")
local registry=require "waterWorks/Registry"
assert(registry.STORE_KEY=="waterWorks.NetworkRegistry.v1")
local stored={waterWorksQuality={biological=.7,chemical=.25,treatment="legacy"}}
local owner={getWaterAmount=function()return 2 end,getWaterMax=function()return 5 end,
    getModData=function()return stored end,isTaintedWater=function()return true end}
assert(branded.getQuality(owner).chemical==.25 and legacy.getQuality(owner).biological==.7)
assert(branded.getQuality(owner).treatment=="legacy")
SandboxVars={waterWorks={EnableWaterSampling=false}}
assert(not branded.isFeatureEnabled("EnableWaterSampling"))
isClient=function()return true end
assert(branded.setQuality(owner,{chemical=0})==false and stored.waterWorksQuality.chemical==.25)
