local inspected={};package.loaded["waterWorks/NetworkInspector"]={open=function(...)inspected[#inspected+1]={...};return true end}
SandboxVars={waterWorks={}}
local treated,heated={},{};package.loaded["waterWorks/CommandClient"]={
    requestTreatment=function(...)treated[#treated+1]={...};return true end,
    requestHeat=function(...)heated[#heated+1]={...};return true end}
local configured,cancelled={},{ };package.loaded["waterWorks/DemandDialog"]={
    open=function(...)configured[#configured+1]={...};return true end,
    cancel=function(...)cancelled[#cancelled+1]={...};return true end}
local queued={}; waterWorks={Registry={describeObject=function(o)if o.node then return {networkId="water",node={id=o.node,kind=o.kind}} end end},queueNetworkAction=function(...)queued[#queued+1]={...}; return true end,
    isFeatureEnabled=function(name)return not(SandboxVars and SandboxVars.waterWorks and SandboxVars.waterWorks[name]==false)end}
local player={}; getSpecificPlayer=function()return player end
Events={OnFillWorldObjectContextMenu={Add=function()end}}
local boxes={};getCore=function()return{getScreenWidth=function()return 1280 end,getScreenHeight=function()return 720 end}end
ISTextBox={new=function(_,x,y,w,h,prompt,initial,target,callback,index,object,descriptor)
    local box={x=x,y=y,w=w,h=h,prompt=prompt,initial=initial,target=target,callback=callback,index=index,object=object,descriptor=descriptor,
        entry={getText=function()return"12.5"end},initialise=function()end,addToUIManager=function()end}
    boxes[#boxes+1]=box;return box
end};package.preload["ISUI/ISTextBox"]=function()return ISTextBox end
ISContextMenu={getNew=function()local options={};return{addOption=function(_,label,target,callback,...)local o={label=label,target=target,callback=callback,args={...}};options[#options+1]=o;return o end,options=options}end}
local menu=dofile(arg[1]); local a={node="a"}; local b={node="b"}; local broken={node=false}
local function context()local options={}; return {addOption=function(_,label,target,callback,...)local o={label=label,target=target,callback=callback,args={...}};options[#options+1]=o;return o end,addSubMenu=function(_,option,sub)option.sub=sub end},options end
local c,o=context(); menu.fill(0,c,{broken,a},false); assert(#o==2 and o[1].label=="Inspect Water Network"and o[2].label:find("Select"))
o[1].callback(o[1].target,table.unpack(o[1].args));assert(#inspected==1,"inspect action must use the server snapshot UI")
o[2].callback(o[2].target,table.unpack(o[2].args)); assert(menu.Selections[0].nodeId=="a")
c,o=context(); menu.fill(0,c,{b},false); assert(#o==6 and o[4].label:find("Transfer") and #o[4].sub.options==7)
o[2].callback(o[2].target,table.unpack(o[2].args)); assert(#queued==1 and queued[1][2]=="connect" and queued[1][3]=="a" and queued[1][4]=="b")
local ten=o[4].sub.options[3];ten.callback(ten.target,table.unpack(ten.args));assert(#queued==2 and queued[2][2]=="flow" and queued[2][7]==10)
local custom=o[4].sub.options[7];custom.callback(custom.target,table.unpack(custom.args));assert(#boxes==1 and boxes[1].object==b)
boxes[1].callback(nil,{internal="OK",parent=boxes[1]},boxes[1].index,boxes[1].object,boxes[1].descriptor)
assert(#queued==3 and queued[3][2]=="flow"and queued[3][7]==12.5)
boxes[1].entry.getText=function()return"101"end
boxes[1].callback(nil,{internal="OK",parent=boxes[1]},boxes[1].index,boxes[1].object,boxes[1].descriptor)
assert(#queued==3 and #boxes==2 and boxes[2].prompt:find("Invalid"),"invalid custom amount must not queue")
o[5].callback(o[5].target,table.unpack(o[5].args));assert(#configured==1 and configured[1][3]=="a"and configured[1][4]=="b")
o[6].callback(o[6].target,table.unpack(o[6].args));assert(#cancelled==1 and cancelled[1][3]=="a"and cancelled[1][4]=="b")
c,o=context(); menu.fill(0,c,{a},false); assert(#o==2 and o[2].label:find("Clear")); o[2].callback(o[2].target,table.unpack(o[2].args)); assert(menu.Selections[0]==nil)
local purifier={node="purifier",kind="treatment"};local tank={node="tank",kind="storage"}
c,o=context();menu.fill(0,c,{purifier},false);o[2].callback(o[2].target,table.unpack(o[2].args))
c,o=context();menu.fill(0,c,{tank},false);assert(#o==8 and o[7].label:find("Sterilize")and o[8].label:find("Heat Water"))
o[7].callback(o[7].target,table.unpack(o[7].args));assert(#treated==1 and treated[1][2]=="purifier"and treated[1][3]=="tank")
o[8].callback(o[8].target,table.unpack(o[8].args));assert(#heated==1 and heated[1][2]=="purifier"and heated[1][3]=="tank"and heated[1][4]==5)
assert(menu.fill(0,c,{broken},true)==nil)

menu.Selections[0]=nil;SandboxVars.waterWorks.EnableNetworkInspection=false
c,o=context();menu.fill(0,c,{a},false);assert(#o==1 and o[1].label:find("Select"),"inspection toggle must hide only inspection")
SandboxVars.waterWorks.EnableNetworkContextActions=false
c,o=context();menu.fill(0,c,{a},false);assert(#o==0,"both disabled surfaces must add no options")
SandboxVars.waterWorks.EnableNetworkInspection=true
c,o=context();menu.fill(0,c,{a},false);assert(#o==1 and o[1].label=="Inspect Water Network","inspection must remain independently available")
SandboxVars.waterWorks.EnableNetworkContextActions=true;SandboxVars.waterWorks.EnableNetworkInspection=true
c,o=context();menu.fill(0,c,{a},false);o[2].callback(o[2].target,table.unpack(o[2].args))
SandboxVars.waterWorks.EnableCustomTransferAmounts=false;SandboxVars.waterWorks.EnableScheduledTransfers=false
c,o=context();menu.fill(0,c,{b},false)
assert(#o==4 and #o[4].sub.options==6,"optional custom and scheduling controls must disappear without changing presets")
assert(menu.Selections[0].nodeId=="a","hiding controls must preserve the existing selection")
print("B47ANCEDWaterworks two-step network context workflow checks passed")
