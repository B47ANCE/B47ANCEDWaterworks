ISBaseTimedAction={derive=function(_,name)local c={Type=name}; c.__index=c; return c end,new=function(self,character)return setmetatable({character=character},{__index=self}) end,stop=function()end,perform=function()end}
package.preload["TimedActions/ISBaseTimedAction"]=function()return ISBaseTimedAction end
local queued={}; ISTimedActionQueue={add=function(a)queued[#queued+1]=a end}; package.preload["TimedActions/ISTimedActionQueue"]=function()return ISTimedActionQueue end
local sent={}; sendClientCommand=function(...)sent[#sent+1]={...}end
Events={OnServerCommand={Add=function()end}}
dofile(arg[1]); dofile(arg[2]); local action=dofile(arg[3])
local player={getX=function()return 0 end,getY=function()return 0 end,getZ=function()return 0 end,isDead=function()return false end,isTimedActionInstant=function()return false end}
local a={getX=function()return 0 end,getY=function()return 0 end,getZ=function()return 0 end}; local b={getX=function()return 1 end,getY=function()return 0 end,getZ=function()return 0 end}
assert(waterWorks.queueNetworkAction(player,"flow","source","target",a,b,2,0)); assert(#queued==1 and queued[1].maxTime==60)
assert(queued[1]:isValid(),"queued action invalid")
assert(queued[1]:complete(),"queued action did not send")
assert(#sent==1,"expected one client command, got "..tostring(#sent))
assert(not queued[1]:complete() and #sent==1,"action repeated")
local far={getX=function()return 20 end,getY=function()return 0 end,getZ=function()return 0 end}
local invalid=action:new(player,"connect","a","b",a,far); assert(not invalid:isValid() and not invalid:complete())
assert(waterWorks.queueNetworkAction(player,"bad","a","b",a,b)==false)
print("B47ANCEDWaterworks timed network-action revalidation checks passed")
