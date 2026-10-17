Events={OnFillWorldObjectContextMenu={Add=function()end}}
local queued={};waterWorks={Registry={describeObject=function(o)return o.node and{node={id=o.node}}or nil end},
    queueMaintenanceAction=function(...)queued[#queued+1]={...};return true end,
    isFeatureEnabled=function()return not(SandboxVars and SandboxVars.waterWorks and SandboxVars.waterWorks.EnableNetworkContextActions==false)end}
local items={};local container={getItems=function()return items end}
local kit={getFullType=function()return"waterWorks.InfrastructurePatchKit"end,getContainer=function()return container end,getTex=function()return"patch"end}
items[1]=kit
local player={getInventory=function()return container end};getSpecificPlayer=function()return player end
local menu=dofile(arg[1]);local object={node="pipe"};local options={}
local context={addOption=function(_,name,target,callback,...)local o={name=name,target=target,callback=callback,args={...}};options[#options+1]=o;return o end}
assert(menu.fill(0,context,{object},true));menu.fill(0,context,{object},false)
assert(#options==1 and options[1].iconTexture=="patch")
assert(options[1].callback(options[1].target,table.unpack(options[1].args)))
assert(#queued==1 and queued[1][2]=="pipe"and queued[1][3]==object and queued[1][4]==kit)
SandboxVars={waterWorks={EnableNetworkContextActions=false}};menu.fill(0,context,{object},false);assert(#options==1)
print("B47ANCEDWaterworks patch-kit context menu checks passed")
