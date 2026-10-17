local configured,cancelled={},{ }
package.loaded["waterWorks/CommandClient"]={
    configureDemand=function(...)configured[#configured+1]={...};return true,"request"end,
    cancelDemand=function(...)cancelled[#cancelled+1]={...};return true,"cancel"end}
local commands=dofile(arg[1]);package.loaded["waterWorks/Commands"]=commands
local boxes={}
getCore=function()return{getScreenWidth=function()return 1280 end,getScreenHeight=function()return 720 end}end
ISTextBox={new=function(_,x,y,w,h,prompt,initial,target,callback,index,state)
    local box={prompt=prompt,initial=initial,target=target,callback=callback,index=index,state=state,
        value=initial,initialise=function()end,addToUIManager=function()end}
    box.entry={getText=function()return box.value end}
    boxes[#boxes+1]=box;return box
end};package.preload["ISUI/ISTextBox"]=function()return ISTextBox end
local dialog=dofile(arg[2]);local player={}
assert(dialog.open(0,player,"source","target")and #boxes==1)
boxes[1].value="2,5";boxes[1].callback(boxes[1].target,{internal="OK",parent=boxes[1]},boxes[1].state)
assert(#boxes==2 and boxes[2].prompt:find("interval"))
boxes[2].value="12";boxes[2].callback(boxes[2].target,{internal="OK",parent=boxes[2]},boxes[2].state)
assert(#configured==1 and configured[1][2]=="source"and configured[1][3]=="target"
    and configured[1][4]==2.5 and configured[1][5]==12)
assert(dialog.open(0,player,"source","target"));local invalid=boxes[#boxes];invalid.value="101"
invalid.callback(invalid.target,{internal="OK",parent=invalid},invalid.state)
assert(#configured==1 and boxes[#boxes].prompt:find("Invalid amount"))
local cancelledBox=boxes[#boxes];cancelledBox.callback(cancelledBox.target,{internal="CANCEL",parent=cancelledBox},cancelledBox.state)
assert(#configured==1,"cancelled prompt must not configure")
assert(dialog.cancel(nil,player,"source","target")and #cancelled==1)
print("B47ANCEDWaterworks scheduled-demand dialog checks passed")
