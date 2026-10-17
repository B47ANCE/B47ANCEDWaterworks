local waterWorks=rawget(_G,"waterWorks") or require "waterWorks/API"
local Registry=waterWorks.Registry or require "waterWorks/Registry"
local Inspector=require "waterWorks/NetworkInspector"
local DemandDialog=require "waterWorks/DemandDialog"
local Menu={Selections={},MIN_TRANSFER=0.01,MAX_TRANSFER=100}

local function describe(object)
    local ok,value=pcall(Registry.describeObject,object)
    return ok and type(value)=="table" and value or nil
end
local function firstNode(worldObjects)
    local seen={}
    for _,object in ipairs(type(worldObjects)=="table" and worldObjects or {}) do
        if object and not seen[object] then
            seen[object]=true; local descriptor=describe(object)
            if descriptor and descriptor.node and descriptor.node.id then return object,descriptor end
        end
    end
end
local function player(index)
    return type(getSpecificPlayer)=="function" and getSpecificPlayer(index) or nil
end
local function selectEndpoint(object,descriptor,index)
    Menu.Selections[index]={object=object,nodeId=descriptor.node.id,networkId=descriptor.networkId,
        kind=descriptor.node.kind}
end
local function clearEndpoint(_,index) Menu.Selections[index]=nil end
local function configureDemand(_,descriptor,index)
    local selected=Menu.Selections[index];local actor=player(index)
    if not selected or not actor or not descriptor or not descriptor.node then return false end
    return DemandDialog.open(index,actor,selected.nodeId,descriptor.node.id)
end
local function cancelDemand(_,descriptor,index)
    local selected=Menu.Selections[index];local actor=player(index)
    if not selected or not actor or not descriptor or not descriptor.node then return false end
    return DemandDialog.cancel(nil,actor,selected.nodeId,descriptor.node.id)
end
local function queue(targetObject,targetDescriptor,index,mode,amount)
    local selected=Menu.Selections[index]; local actor=player(index)
    if not selected or not actor or not targetObject or not targetDescriptor then return false end
    return waterWorks.queueNetworkAction(actor,mode,selected.nodeId,targetDescriptor.node.id,
        selected.object,targetObject,mode=="flow" and amount or nil,0)
end
local function treat(_,descriptor,index)
    local selected=Menu.Selections[index];local actor=player(index)
    if not selected or not actor or not descriptor or not descriptor.node then return false end
    local current=descriptor.node
    local deviceId,targetId
    if selected.kind=="treatment"and(current.kind=="storage"or current.kind=="fixture")then
        deviceId,targetId=selected.nodeId,current.id
    elseif current.kind=="treatment"and(selected.kind=="storage"or selected.kind=="fixture")then
        deviceId,targetId=current.id,selected.nodeId
    else return false end
    return (waterWorks.CommandClient or require "waterWorks/CommandClient").requestTreatment(actor,deviceId,targetId,"boiled")
end
local function heat(_,descriptor,index)
    local selected=Menu.Selections[index];local actor=player(index)
    if not selected or not actor or not descriptor or not descriptor.node then return false end
    local current=descriptor.node;local deviceId,targetId
    if selected.kind=="treatment"and(current.kind=="storage"or current.kind=="fixture")then
        deviceId,targetId=selected.nodeId,current.id
    elseif current.kind=="treatment"and(selected.kind=="storage"or selected.kind=="fixture")then
        deviceId,targetId=current.id,selected.nodeId
    else return false end
    return (waterWorks.CommandClient or require "waterWorks/CommandClient").requestHeat(actor,deviceId,targetId,5)
end

local function finite(value)
    return type(value)=="number"and value==value and value~=math.huge and value~=-math.huge
end
local function openCustomTransfer(targetObject,targetDescriptor,index,message)
    local loaded=pcall(require,"ISUI/ISTextBox")
    if not loaded or not rawget(_G,"ISTextBox")or not rawget(_G,"getCore")then return false,"amount dialog unavailable"end
    local core=getCore();if not core then return false,"screen unavailable"end
    local width,height=420,180
    local box=ISTextBox:new(math.floor((core:getScreenWidth()-width)/2),math.floor((core:getScreenHeight()-height)/2),
        width,height,message or"Transfer amount (0.01-100 units)","1",nil,Menu.onCustomTransfer,index,targetObject,targetDescriptor)
    box:initialise();box:addToUIManager()
    if rawget(_G,"JoypadState")and JoypadState.players and JoypadState.players[index+1]and rawget(_G,"setJoypadFocus")then
        setJoypadFocus(index,box)
    end
    return true,box
end
function Menu.onCustomTransfer(_,button,index,targetObject,targetDescriptor)
    if not button or button.internal~="OK"then return false end
    local entry=button.parent and button.parent.entry
    local ok,text=pcall(function()return entry and entry:getText()end)
    local normalized=ok and tostring(text or""):gsub(",",".")or""
    local amount=tonumber(normalized)
    if not finite(amount)or amount<Menu.MIN_TRANSFER or amount>Menu.MAX_TRANSFER then
        return openCustomTransfer(targetObject,targetDescriptor,index,"Invalid amount. Enter 0.01-100 units")
    end
    return queue(targetObject,targetDescriptor,index,"flow",amount)
end
Menu.openCustomTransfer=openCustomTransfer

function Menu.fill(index,context,worldObjects,test)
    if not context or type(context.addOption)~="function" then return end
    local object,descriptor=firstNode(worldObjects); if not object then return end
    if test then return true end
    if waterWorks.isFeatureEnabled("EnableNetworkInspection")then
        context:addOption("Inspect Water Network",object,function(_,playerIndex,entry)
            local actor=player(playerIndex);if actor then Inspector.open(actor,entry,playerIndex)end
        end,index,descriptor)
    end
    if not waterWorks.isFeatureEnabled("EnableNetworkContextActions")then return end
    local selected=Menu.Selections[index]
    if not selected then
        context:addOption("Water Network: Select Endpoint",object,selectEndpoint,descriptor,index)
    elseif selected.object==object or selected.nodeId==descriptor.node.id then
        context:addOption("Water Network: Clear Selection",object,clearEndpoint,index)
    else
        context:addOption("Water Network: Connect Selected",object,queue,descriptor,index,"connect")
        context:addOption("Water Network: Disconnect Selected",object,queue,descriptor,index,"disconnect")
        local transfer=context:addOption("Water Network: Transfer Water",object,nil)
        local sub=ISContextMenu:getNew(context);context:addSubMenu(transfer,sub)
        for _,amount in ipairs({1,5,10,25,50,100}) do
            sub:addOption("Transfer "..tostring(amount).." Unit"..(amount==1 and "" or "s"),object,queue,descriptor,index,"flow",amount)
        end
        if waterWorks.isFeatureEnabled("EnableCustomTransferAmounts")then
            sub:addOption("Custom Amount...",object,openCustomTransfer,descriptor,index)
        end
        if waterWorks.isFeatureEnabled("EnableScheduledTransfers")then
            context:addOption("Water Network: Schedule/Update Transfer",object,configureDemand,descriptor,index)
            context:addOption("Water Network: Cancel Scheduled Transfer",object,cancelDemand,descriptor,index)
        end
        local a,b=selected.kind,descriptor.node.kind
        if (a=="treatment"and(b=="storage"or b=="fixture"))
            or(b=="treatment"and(a=="storage"or a=="fixture"))then
            context:addOption("Water Network: Heat-Sterilize Water",object,treat,descriptor,index)
            context:addOption("Water Network: Heat Water (+5 C)",object,heat,descriptor,index)
        end
    end
end

if Events and Events.OnFillWorldObjectContextMenu then Events.OnFillWorldObjectContextMenu.Add(Menu.fill) end
waterWorks.NetworkContextMenu=Menu
return Menu
