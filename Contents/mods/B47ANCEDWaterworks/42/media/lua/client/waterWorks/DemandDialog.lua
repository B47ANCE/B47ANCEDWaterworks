local Client=require "waterWorks/CommandClient"
local Commands=require "waterWorks/Commands"
local Dialog={}

local function finite(value)return type(value)=="number"and value==value and value~=math.huge and value~=-math.huge end
local function read(button)
    local entry=button and button.parent and button.parent.entry
    local ok,value=pcall(function()return entry and entry:getText()end)
    return ok and tostring(value or""):gsub(",",".")or""
end
local function openBox(index,prompt,initial,callback,state)
    local loaded=pcall(require,"ISUI/ISTextBox")
    if not loaded or not rawget(_G,"ISTextBox")or not rawget(_G,"getCore")then return false,"demand dialog unavailable"end
    local core=getCore();if not core then return false,"screen unavailable"end
    local width,height=440,180
    local box=ISTextBox:new(math.floor((core:getScreenWidth()-width)/2),math.floor((core:getScreenHeight()-height)/2),
        width,height,prompt,initial,Dialog,callback,index,state)
    box:initialise();box:addToUIManager()
    if rawget(_G,"JoypadState")and JoypadState.players and JoypadState.players[index+1]and rawget(_G,"setJoypadFocus")then
        setJoypadFocus(index,box)
    end
    return true,box
end
local function amountBox(state,message)
    return openBox(state.playerIndex,message or"Repeated transfer amount (0.01-100 units)","1",Dialog.onAmount,state)
end
local function intervalBox(state,message)
    return openBox(state.playerIndex,message or"Repeat interval in game hours (0.01-8760)","24",Dialog.onInterval,state)
end
function Dialog.onAmount(_,button,state)
    if not button or button.internal~="OK"or type(state)~="table"then return false end
    local value=tonumber(read(button))
    if not finite(value)or value<=0 or value>Commands.MAX_FLOW_AMOUNT then
        return amountBox(state,"Invalid amount. Enter 0.01-100 units")
    end
    state.amount=value;return intervalBox(state)
end
function Dialog.onInterval(_,button,state)
    if not button or button.internal~="OK"or type(state)~="table"then return false end
    local value=tonumber(read(button))
    if not finite(value)or value<Commands.MIN_DEMAND_INTERVAL or value>Commands.MAX_DEMAND_INTERVAL then
        return intervalBox(state,"Invalid interval. Enter 0.01-8760 game hours")
    end
    return Client.configureDemand(state.player,state.sourceId,state.targetId,state.amount,value)
end
function Dialog.open(playerIndex,player,sourceId,targetId)
    if not player or type(sourceId)~="string"or type(targetId)~="string"or sourceId==targetId then
        return false,"valid demand route required"
    end
    return amountBox({playerIndex=playerIndex or 0,player=player,sourceId=sourceId,targetId=targetId})
end
function Dialog.cancel(_,player,sourceId,targetId)return Client.cancelDemand(player,sourceId,targetId)end
return Dialog
