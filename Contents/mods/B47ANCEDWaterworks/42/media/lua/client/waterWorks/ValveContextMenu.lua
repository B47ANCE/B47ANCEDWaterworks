local waterWorks=rawget(_G,"waterWorks")or require "waterWorks/API"
local Client=waterWorks.CommandClient or require "waterWorks/CommandClient"
local Valves=waterWorks.FirstPartyValves or require "waterWorks/FirstPartyValves"
local Registry=waterWorks.Registry or require "waterWorks/Registry"
local Menu={}

local function call(object,name,...)
    local ok,fn=pcall(function()return object and object[name]end)
    if not ok or type(fn)~="function"then return nil end
    local called,value=pcall(fn,object,...);return called and value or nil
end
local function valveObject(candidate)
    local item=call(candidate,"getItem")
    return item and call(item,"getFullType")==Valves.INLINE_TYPE and candidate or nil
end
local function claim(object,index)
    local actor=type(getSpecificPlayer)=="function"and getSpecificPlayer(index)or nil
    return actor and Client.claimPlacedValve(actor,object)or false
end
local function setOpen(_,index,nodeId,open)
    local actor=type(getSpecificPlayer)=="function"and getSpecificPlayer(index)or nil
    return actor and Client.setValveOpen(actor,nodeId,open)or false
end

function Menu.fill(index,context,worldObjects,test)
    if not waterWorks.isFeatureEnabled("EnableNetworkContextActions")then return end
    if not context or type(context.addOption)~="function"then return end
    local seen={}
    for _,candidate in ipairs(type(worldObjects)=="table"and worldObjects or{})do
        local object=valveObject(candidate)
        if object and not seen[object]then
            seen[object]=true;local registered=Valves.inspect(object)
            if test then return true end
            local item=call(object,"getItem");local texture=call(item,"getTex");local option
            if not registered then
                option=context:addOption("Register Inline Water Valve",object,claim,index)
            else
                local descriptor=Registry.describeObject(object);local nodeId=descriptor and descriptor.node and descriptor.node.id
                if nodeId then
                    local open=registered.open~=false
                    option=context:addOption(open and "Close Inline Water Valve"or "Open Inline Water Valve",
                        object,setOpen,index,nodeId,not open)
                end
            end
            if option and texture then option.iconTexture=texture end
        end
    end
end

if Events and Events.OnFillWorldObjectContextMenu then Events.OnFillWorldObjectContextMenu.Add(Menu.fill)end
waterWorks.ValveContextMenu=Menu
return Menu
