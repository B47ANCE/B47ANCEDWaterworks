local sent={};sendClientCommand=function(...)sent[#sent+1]={...}end
local player={};getSpecificPlayer=function()return player end
Events={OnServerCommand={Add=function()end},OnTick={Add=function()end},OnFillWorldObjectContextMenu={Add=function()end}}
local commands=dofile(arg[1]);dofile(arg[2]);local valves={INLINE_TYPE="waterWorks.InlineShutoffValve",MARKER_KEY="waterWorksInlineValve.v1"}
waterWorks=waterWorks or{};waterWorks.FirstPartyValves=valves
waterWorks.isFeatureEnabled=function()return not(SandboxVars and SandboxVars.waterWorks and SandboxVars.waterWorks.EnableNetworkContextActions==false)end
function valves.inspect(object)local value=object.md[valves.MARKER_KEY];return value and{open=value.open~=false}or nil end
waterWorks.Registry={describeObject=function()return{node={id="waterWorks.inlineValve:1"}}end}
local menu=dofile(arg[3]);local item={getFullType=function()return valves.INLINE_TYPE end,getID=function()return 9 end,getTex=function()return"valve"end}
local object={md={},getItem=function()return item end,getX=function()return 1 end,getY=function()return 1 end,getZ=function()return 0 end}
local options={};local context={addOption=function(_,label,target,callback,...)local option={};options[#options+1]={label=label,target=target,callback=callback,args={...},option=option};return option end}
menu.fill(0,context,{object},false);assert(#options==1 and options[1].label=="Register Inline Water Valve")
assert(options[1].callback(options[1].target,table.unpack(options[1].args))and sent[1][3]==commands.CLAIM_VALVE)
object.md[valves.MARKER_KEY]={schemaVersion=1,networkId="WATER",open=true};options={};menu.fill(0,context,{object},false)
assert(options[1].label=="Close Inline Water Valve");assert(options[1].callback(options[1].target,table.unpack(options[1].args)))
assert(sent[#sent][3]==commands.SET_VALVE and sent[#sent][4].open==false)
SandboxVars={waterWorks={EnableNetworkContextActions=false}};menu.fill(0,context,{object},false);assert(#options==1)
print("B47ANCEDWaterworks nil-safe valve context action checks passed")
