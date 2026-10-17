local sent={}; sendClientCommand=function(...) sent[#sent+1]={...} end
waterWorks={isFeatureEnabled=function()return not(SandboxVars and SandboxVars.waterWorks and SandboxVars.waterWorks.EnableNetworkContextActions==false)end}
local player={}; getSpecificPlayer=function()return player end
Events={OnServerCommand={Add=function()end},OnFillWorldObjectContextMenu={Add=function(_,fn)Events.fill=fn end}}
local commands=dofile(arg[1]); dofile(arg[2]); local menu=dofile(arg[3])
local item={getFullType=function()return "waterWorks.PortableTransferPump" end,getID=function()return 9 end,getTex=function()return "pump-icon" end}
local object={getItem=function()return item end,getX=function()return 4 end,getY=function()return 5 end,getZ=function()return 0 end}
local options={}; local context={addOption=function(_,label,target,callback,index)local o={}; options[#options+1]={label=label,target=target,callback=callback,index=index,option=o}; return o end}
assert(menu.fill(0,context,{object,object},false)==nil and #options==1)
assert(options[1].label=="Register Portable Pump" and options[1].option.iconTexture=="pump-icon")
assert(options[1].callback(options[1].target,options[1].index)==true and #sent==1)
assert(sent[1][3]==commands.CLAIM_PUMP and sent[1][4].itemId=="9")
local broken={getItem=function()error("bad mod item")end}; menu.fill(0,context,{broken},false); assert(#options==1)
SandboxVars={waterWorks={EnableNetworkContextActions=false}};menu.fill(0,context,{object},false);assert(#options==1,"disabled infrastructure actions must add nothing")
print("B47ANCEDWaterworks nil-safe portable-pump context action checks passed")
