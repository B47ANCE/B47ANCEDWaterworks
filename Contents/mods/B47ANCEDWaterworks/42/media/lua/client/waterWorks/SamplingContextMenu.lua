local waterWorks=rawget(_G,"waterWorks")or require "waterWorks/API"
local Sampling=waterWorks.Sampling or require "waterWorks/Sampling"
local Menu={MAX_OBJECTS=128,MAX_ITEMS=512}
local function call(object,name,...)
    local ok,fn=pcall(function()return object and object[name]end);if not ok or type(fn)~="function"then return nil end
    local called,value=pcall(fn,object,...);if called then return value end;return nil
end
local function each(list,callback,limit)
    limit=limit or Menu.MAX_ITEMS
    if type(list)=="table"then local count=0;for _,value in pairs(list)do count=count+1;if count>limit then break end
        if callback(value)==false then return false end end;return true end
    local size=tonumber(call(list,"size"))or 0
    for index=0,math.min(size,limit)-1 do if callback(call(list,"get",index))==false then return false end end
end
local function target(objects)
    local seen,count={},0
    for _,object in ipairs(type(objects)=="table"and objects or{})do
        count=count+1;if count>Menu.MAX_OBJECTS then break end
        if object and not seen[object]then
            seen[object]=true
            local ok,adapter=pcall(waterWorks.getContainer,object)
            if ok and adapter then
                local amountOk,amount=pcall(adapter.getAmount,adapter)
                if amountOk and tonumber(amount)and amount>0 then return object end
            end
        end
    end
end
local function findKit(player)
    local root=call(player,"getInventory");if not root then return nil end
    local queue={root};local head,visited=1,0
    while head<=#queue and visited<Menu.MAX_ITEMS do
        local container=queue[head];head=head+1;local found=nil
        each(call(container,"getItems"),function(item)
            visited=visited+1;if visited>Menu.MAX_ITEMS then return false end
            if call(item,"getFullType")==Sampling.KIT_TYPE and call(item,"getContainer")==container then
                local uses,delta=tonumber(call(item,"getCurrentUsesFloat")),tonumber(call(item,"getUseDelta"))
                if uses and delta and uses+0.0001>=delta then found=item;return false end
            end
            local nested=call(item,"getInventory");if nested then queue[#queue+1]=nested end
        end,Menu.MAX_ITEMS)
        if found then return found end
    end
end
local function queue(object,playerIndex,mode,kit)
    local player=type(getSpecificPlayer)=="function"and getSpecificPlayer(playerIndex)or nil
    if not player then return false end;return waterWorks.queueSamplingAction(player,object,mode,kit)
end
function Menu.fill(playerIndex,context,worldObjects,test)
    if not Sampling.isEnabled()or not context or type(context.addOption)~="function"then return end
    local player=type(getSpecificPlayer)=="function"and getSpecificPlayer(playerIndex)or nil
    local object=target(worldObjects);if not object or not player then return end
    if test then return true end
    context:addOption("Inspect Water",object,queue,playerIndex,"inspect",nil)
    local kit=findKit(player)
    if kit then
        local option=context:addOption("Test Water Quality",object,queue,playerIndex,"kit",kit)
        local texture=call(kit,"getTex");if option and texture then option.iconTexture=texture end
    end
end
if Events and Events.OnFillWorldObjectContextMenu then Events.OnFillWorldObjectContextMenu.Add(Menu.fill)end
waterWorks.SamplingContextMenu=Menu
return Menu
