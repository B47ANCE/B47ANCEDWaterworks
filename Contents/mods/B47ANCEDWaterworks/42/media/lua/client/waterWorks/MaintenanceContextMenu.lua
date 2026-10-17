local waterWorks=rawget(_G,"waterWorks")or require "waterWorks/API"
local Registry=waterWorks.Registry or require "waterWorks/Registry"
local Menu={MAX_ITEMS=256}
local function call(object,name,...)
    local ok,fn=pcall(function()return object and object[name]end);if not ok or type(fn)~="function"then return nil end
    local called,value=pcall(fn,object,...);return called and value or nil
end
local function each(list,callback)
    if type(list)=="table"then local count=0;for _,v in pairs(list)do count=count+1;if count>Menu.MAX_ITEMS then return nil end
        if callback(v)==false then return false end end;return true end
    local size=tonumber(call(list,"size"))or 0
    for i=0,math.min(size,Menu.MAX_ITEMS)-1 do if callback(call(list,"get",i))==false then return false end end
end
local function patchKit(player)
    local root=call(player,"getInventory");if not root then return nil end
    local queue={root};local head,seen=1,0
    while head<=#queue and seen<Menu.MAX_ITEMS do
        local container=queue[head];head=head+1;local items=call(container,"getItems");local found
        each(items,function(item)
            seen=seen+1
            if call(item,"getFullType")=="waterWorks.InfrastructurePatchKit"and call(item,"getContainer")==container then found=item;return false end
            local nested=call(item,"getInventory");if nested then queue[#queue+1]=nested end
        end)
        if found then return found end
    end
end
local function firstNode(objects)
    for _,object in ipairs(type(objects)=="table"and objects or{})do
        local ok,value=pcall(Registry.describeObject,object)
        if ok and type(value)=="table"and value.node and value.node.id then return object,value.node.id end
    end
end
local function queue(_,playerIndex,nodeId,kit)
    local player=type(getSpecificPlayer)=="function"and getSpecificPlayer(playerIndex)or nil
    if not player then return false end
    return waterWorks.queueMaintenanceAction(player,nodeId,_,kit)
end
function Menu.fill(playerIndex,context,worldObjects,test)
    if not waterWorks.isFeatureEnabled("EnableNetworkContextActions")then return end
    if not context or type(context.addOption)~="function"then return end
    local player=type(getSpecificPlayer)=="function"and getSpecificPlayer(playerIndex)or nil
    local object,nodeId=firstNode(worldObjects);local kit=player and patchKit(player)or nil
    if not object or not kit then return end;if test then return true end
    local option=context:addOption("Repair Water Infrastructure",object,queue,playerIndex,nodeId,kit)
    local texture=call(kit,"getTex");if option and texture then option.iconTexture=texture end
end
if Events and Events.OnFillWorldObjectContextMenu then Events.OnFillWorldObjectContextMenu.Add(Menu.fill)end
waterWorks.MaintenanceContextMenu=Menu
return Menu
