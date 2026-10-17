ISBaseTimedAction={derive=function(_,name)local c={Type=name};c.__index=c;return c end,
    new=function(self,character)return setmetatable({character=character},{__index=self})end,stop=function()end,perform=function()end}
package.preload["TimedActions/ISBaseTimedAction"]=function()return ISBaseTimedAction end
local queued={};ISTimedActionQueue={add=function(action)queued[#queued+1]=action end}
package.preload["TimedActions/ISTimedActionQueue"]=function()return ISTimedActionQueue end
local sent={};sendClientCommand=function(...)sent[#sent+1]={...}end;Events={OnServerCommand={Add=function()end}}
SandboxVars={waterWorks={EnableWaterSampling=true,SamplingTimeMultiplier=2}}
local api=dofile(arg[1]);dofile(arg[2]);dofile(arg[3]);dofile(arg[4]);local action=dofile(arg[5])
local fluid={getAmount=function()return 2 end,getCapacity=function()return 5 end,isTaintedWater=function()return false end}
local object={getFluidContainer=function()return fluid end,getModData=function()return{}end,
    getX=function()return 1 end,getY=function()return 0 end,getZ=function()return 0 end,
    getObjectIndex=function()return 2 end,getSpriteName=function()return"fixtures_sinks_01_0"end}
local container={};local kit={getID=function()return 8 end,getFullType=function()return"waterWorks.WaterTestKit"end,
    getContainer=function()return container end,getCurrentUsesFloat=function()return 1 end,getUseDelta=function()return .1 end}
local player={getX=function()return 0 end,getY=function()return 0 end,getZ=function()return 0 end,
    isDead=function()return false end,isTimedActionInstant=function()return false end}
assert(waterWorks.queueSamplingAction(player,object,"kit",kit)and#queued==1 and queued[1].maxTime==240)
assert(queued[1]:isValid(),"queued sampling action invalid")
assert(queued[1]:complete(),"queued sampling action did not send")
assert(sent[1]and sent[1][4].mode=="kit"and sent[1][4].kitId=="8","sampling payload mismatch")
assert(not queued[1]:complete()and#sent==1,"sampling action must be one-shot")
SandboxVars.waterWorks.EnableWaterSampling=false;assert(not action:new(player,object,"inspect",nil):isValid())
print("B47ANCEDWaterworks timed sampling-action checks passed")
