local sent={};sendClientCommand=function(...)sent[#sent+1]={...}end
local player={};getSpecificPlayer=function()return player end
Events={OnServerCommand={Add=function()end},OnTick={Add=function()end},OnFillWorldObjectContextMenu={Add=function()end}}
local commands=dofile(arg[1]);dofile(arg[2]);waterWorks.VanillaProviders={inspectClaim=function(object)return object.claimed and{}or nil end}
waterWorks.isFeatureEnabled=function()return not(SandboxVars and SandboxVars.waterWorks and SandboxVars.waterWorks.EnableNetworkContextActions==false)end
local menu=dofile(arg[3]);local object={md={}}
function object:getFluidContainer()return{}end;function object:getModData()return self.md end
function object:getX()return 1 end;function object:getY()return 2 end;function object:getZ()return 0 end
function object:getObjectIndex()return 4 end;function object:getSpriteName()return"fixtures_sinks_01_0"end
local options={};local context={addOption=function(_,label,target,callback,index)options[#options+1]={label=label,target=target,callback=callback,index=index}end}
menu.fill(0,context,{object,object},false);assert(#options==1 and options[1].label=="Register Water Infrastructure")
assert(options[1].callback(options[1].target,options[1].index)and sent[1][3]==commands.CLAIM_FIXTURE)
object.claimed=true;menu.fill(0,context,{object},false);assert(#options==1,"claimed fixtures must not offer duplicate registration")
object.claimed=false;SandboxVars={waterWorks={EnableNetworkContextActions=false}};menu.fill(0,context,{object},false);assert(#options==1)
print("B47ANCEDWaterworks nil-safe vanilla fixture context action checks passed")
