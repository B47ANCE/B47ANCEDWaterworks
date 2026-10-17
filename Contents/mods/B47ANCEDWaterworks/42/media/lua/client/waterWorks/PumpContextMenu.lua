local waterWorks=rawget(_G,"waterWorks") or require "waterWorks/API"
local Client=waterWorks.CommandClient or require "waterWorks/CommandClient"
local Menu={}

local function call(object,name,...)
    local ok,fn=pcall(function() return object and object[name] end)
    if not ok or type(fn)~="function" then return nil end
    local called,value=pcall(fn,object,...); return called and value or nil
end
local function pumpObject(candidate)
    local item=call(candidate,"getItem")
    return item and call(item,"getFullType")=="waterWorks.PortableTransferPump" and candidate or nil
end
local function activate(worldObject,playerIndex)
    local player=type(getSpecificPlayer)=="function" and getSpecificPlayer(playerIndex) or nil
    if not player or not worldObject then return false end
    local ok,reason=Client.claimPlacedPump(player,worldObject)
    if not ok and print then print("[B47ANCEDWaterworks] Pump registration failed safely: "..tostring(reason)) end
    return ok
end

function Menu.fill(playerIndex,context,worldObjects,test)
    if not waterWorks.isFeatureEnabled("EnableNetworkContextActions")then return end
    if not context or type(context.addOption)~="function" then return end
    local seen={}
    for _,candidate in ipairs(type(worldObjects)=="table" and worldObjects or {}) do
        local object=pumpObject(candidate)
        if object and not seen[object] then
            seen[object]=true
            if test then return true end
            local option=context:addOption("Register Portable Pump",object,activate,playerIndex)
            local item=call(object,"getItem"); local texture=call(item,"getTex")
            if option and texture then option.iconTexture=texture end
        end
    end
end

if Events and Events.OnFillWorldObjectContextMenu then Events.OnFillWorldObjectContextMenu.Add(Menu.fill) end
waterWorks.PumpContextMenu=Menu
return Menu
