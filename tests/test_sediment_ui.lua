local f=dofile("tests/helpers/sediment_fixture.lua")
assert(f.H.claim(f.store,f.world,f.actor))
ISBaseTimedAction={derive=function(_,name)local c={Type=name};c.__index=c;return c end,
    new=function(self,actor)return setmetatable({character=actor},{__index=self})end,
    perform=function()end,stop=function()end}
package.preload["TimedActions/ISBaseTimedAction"]=function()return ISBaseTimedAction end
local queued={};ISTimedActionQueue={add=function(action)queued[#queued+1]=action end}
package.preload["TimedActions/ISTimedActionQueue"]=function()return ISTimedActionQueue end
Events={OnServerCommand={Add=function()end},OnTick={Add=function()end},OnFillWorldObjectContextMenu={Add=function()end}}
local sent={};sendClientCommand=function(...)sent[#sent+1]={...}end
getTimestampMs=function()return 123456789 end
getSpecificPlayer=function()return f.actor end
getText=function(key,...)return key end
waterWorks.NetworkContextMenu={Selections={}}
local Client=require "waterWorks/CommandClient"
local Action=require "waterWorks/SedimentAction"
local Menu=require "waterWorks/SedimentContextMenu"
local options={};local context={addOption=function(_,name,target,fn,...)
    local option={name=name,target=target,fn=fn,args={...}};options[#options+1]=option;return option end}
local function option(suffix)for _,entry in ipairs(options)do if entry.name=="UI_B47ANCEDWaterworks_Sediment"..suffix then return entry end end end
Menu.fill(0,context,{f.world,f.world},false)
assert(option("Install")and option("Empty")and option("Hazards"))
local install=option("Install");assert(install.fn(install.target,unpack(install.args)))
local action=queued[1];assert(action.maxTime==120 and action:isValid())
action:perform();action:perform()
assert(#sent==1 and sent[1][4].operation=="replace"and sent[1][4].mediaId==tostring(f.cartridge.id))
assert(f.removed()==0,"client timing may submit intent but must not remove media")
local node=f.H.presentation(f.world).nodeId
assert(Client.receive("waterWorks","connectionResult",{requestId=sent[1][4].requestId,ok=false}))
options={};Menu.fill(0,context,{f.world},false);assert(option("LastFailed"))
local cancelled=Action:new(f.actor,f.world,"replace",f.cartridge)
cancelled:stop();cancelled:perform();assert(#sent==1)
local dead=Action:new(f.actor,f.world,"replace",f.cartridge)
f.actor.dead=true;dead:perform();assert(#sent==1);f.actor.dead=false
local stale=Action:new(f.actor,f.world,"replace",f.cartridge)
f.world.md[f.H.WORLD_KEY].generation=99
stale:perform();assert(#sent==1)
f.world.md[f.H.WORLD_KEY].generation=0
assert(f.H.replace(f.store,node,f.actor,tostring(f.cartridge.id),"ui:install",0))
options={};Menu.fill(0,context,{f.world},false)
assert(option("Capacity")and not option("Replace"),"full fresh media must not offer pointless replacement")
waterWorks.NetworkContextMenu.Selections[0]={kind="filter",object=f.world,nodeId=node}
options={};Menu.fill(0,context,{f.target},false);assert(option("Filter"))
local filter=option("Filter");assert(filter.fn(filter.target,unpack(filter.args)))
queued[#queued]:perform();assert(#sent==2 and sent[2][4].operation=="filter"and sent[2][4].targetId==f.targetId)
assert(f.api.getQuality(f.target).particulate==1,"client must not mutate water quality")
SandboxVars={waterWorks={EnableSedimentFilters=false}}
options={};Menu.fill(0,context,{f.world,f.target},false)
assert(option("Capacity")and not option("Filter")and not option("Replace"),"disabled gameplay preserves read-only inspection")
SandboxVars.waterWorks.EnableNetworkInspection=false
options={};Menu.fill(0,context,{f.world},false);assert(#options==0)
print("sediment UI: localized/state-aware actions, intent-only completion, cancellation, staleness and sandbox controls PASS")
