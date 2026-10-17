ISBaseTimedAction={derive=function(_,name)local c={Type=name};c.__index=c;return c end,
    new=function(self,character)return setmetatable({character=character},{__index=self})end,stop=function()end,perform=function()end}
package.preload["TimedActions/ISBaseTimedAction"]=function()return ISBaseTimedAction end
local queued={};ISTimedActionQueue={add=function(a)queued[#queued+1]=a end}
package.preload["TimedActions/ISTimedActionQueue"]=function()return ISTimedActionQueue end
local sent={};sendClientCommand=function(...)sent[#sent+1]={...}end;Events={OnServerCommand={Add=function()end}}
dofile(arg[1]);dofile(arg[2]);local action=dofile(arg[3])
local container={};local kit={getID=function()return 44 end,getFullType=function()return"waterWorks.InfrastructurePatchKit"end,getContainer=function()return container end}
local player={getX=function()return 0 end,getY=function()return 0 end,getZ=function()return 0 end,isDead=function()return false end,isTimedActionInstant=function()return false end}
local object={getX=function()return 1 end,getY=function()return 0 end,getZ=function()return 0 end}
assert(waterWorks.queueMaintenanceAction(player,"pipe",object,kit));assert(#queued==1 and queued[1].maxTime==120)
assert(queued[1]:isValid()and queued[1]:complete());assert(sent[1][4].nodeId=="pipe"and sent[1][4].kitId=="44")
assert(not queued[1]:complete()and #sent==1,"maintenance action must be one-shot")
kit.getContainer=function()return nil end;assert(not action:new(player,"pipe",object,kit):isValid())
print("B47ANCEDWaterworks timed maintenance-action checks passed")
