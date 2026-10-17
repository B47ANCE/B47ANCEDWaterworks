Events={OnFillWorldObjectContextMenu={Add=function()end}}
waterWorks={isFeatureEnabled=function()return not(SandboxVars and SandboxVars.waterWorks and SandboxVars.waterWorks.EnableNetworkContextActions==false)end}
local sent={};sendClientCommand=function(...)sent[#sent+1]={...}end
getSpecificPlayer=function()return {}end
local commands=dofile(arg[1]);dofile(arg[2]);local menu=dofile(arg[3])
local item={getFullType=function()return"waterWorks.ElectricWaterPurifier"end,getID=function()return 7 end,
    getTex=function()return"purifier-icon"end}
local object={getItem=function()return item end,getX=function()return 1 end,getY=function()return 2 end,getZ=function()return 0 end}
local options={};local context={addOption=function(_,name,target,callback,...)
    local option={name=name,target=target,callback=callback,args={...}};options[#options+1]=option;return option end}
assert(menu.fill(0,context,{object},true))
menu.fill(0,context,{object},false);assert(#options==1 and options[1].iconTexture=="purifier-icon")
assert(options[1].callback(options[1].target,options[1].args[1]))
assert(sent[1][3]==commands.CLAIM_TREATMENT and sent[1][4].itemId=="7")
SandboxVars={waterWorks={EnableNetworkContextActions=false}};menu.fill(0,context,{object},false);assert(#options==1)
print("B47ANCEDWaterworks nil-safe electric-purifier context action checks passed")
