local queued={};local kit={}
local itemContainer={};function kit:getFullType()return"waterWorks.WaterTestKit"end;function kit:getContainer()return itemContainer end
function kit:getCurrentUsesFloat()return 1 end;function kit:getUseDelta()return .1 end;function kit:getTex()return"kit-icon"end
local items={kit};function itemContainer:getItems()return items end
local player={getInventory=function()return itemContainer end};getSpecificPlayer=function()return player end
Events={OnFillWorldObjectContextMenu={Add=function()end}}
local adapter={getAmount=function()return 2 end};waterWorks={Sampling={KIT_TYPE="waterWorks.WaterTestKit",isEnabled=function()return true end},
    getContainer=function(object)if object.compatible then return adapter end end,
    queueSamplingAction=function(actor,object,mode,selected)queued[#queued+1]={actor,object,mode,selected};return true end}
local menu=dofile(arg[1]);local object={compatible=true};local options={}
local context={addOption=function(_,label,target,callback,...)local value={label=label,target=target,callback=callback,args={...}}
    options[#options+1]=value;return value end}
menu.fill(0,context,{object,object,{broken=true}},false)
assert(#options==2 and options[1].label=="Inspect Water"and options[2].label=="Test Water Quality")
assert(options[2].iconTexture=="kit-icon")
assert(options[1].callback(options[1].target,table.unpack(options[1].args)))
assert(options[2].callback(options[2].target,table.unpack(options[2].args)))
assert(queued[1][3]=="inspect"and queued[2][3]=="kit"and queued[2][4]==kit)
items[1]=nil;options={};menu.fill(0,context,{object},false);assert(#options==1,"inspection must remain available without a kit")
assert(menu.fill(0,nil,{object},false)==nil)
print("B47ANCEDWaterworks nil-safe sampling context menu checks passed")
