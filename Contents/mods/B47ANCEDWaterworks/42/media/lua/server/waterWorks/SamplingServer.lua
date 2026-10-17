local waterWorks=rawget(_G,"waterWorks")or require "waterWorks/API"
local Sampling=waterWorks.Sampling or require "waterWorks/Sampling"
local Commands=require "waterWorks/Commands"
local Server={MAX_REQUESTS_PER_TICK=4,MAX_CACHE=64,REACH=3,MAX_OBJECTS=128}
local allowances=setmetatable({},{__mode="k"});local caches=setmetatable({},{__mode="k"})

local function call(object,name,...)
    local ok,fn=pcall(function()return object and object[name]end);if not ok or type(fn)~="function"then return nil,false end
    local called,value=pcall(fn,object,...);if called then return value,true end;return nil,false
end
local function valid(value,maximum)
    return type(value)=="string"and value~=""and#value<=maximum and not value:find("[%c]",1)
end
local function each(list,callback,limit)
    limit=limit or Server.MAX_OBJECTS
    if type(list)=="table"then
        local count=0;for _,value in pairs(list)do count=count+1;if count>limit then break end
            if callback(value)==false then return false end end;return true
    end
    local size=tonumber((call(list,"size")))or 0
    for index=0,math.min(size,limit)-1 do if callback(call(list,"get",index))==false then return false end end
    return true
end
local function closeEnough(player,x,y,z)
    local px,py,pz=tonumber((call(player,"getX"))),tonumber((call(player,"getY"))),tonumber((call(player,"getZ")))
    if not px or not py or not pz then return false end
    local dx,dy,dz=px-x,py-y,(pz-z)*3;return dx*dx+dy*dy+dz*dz<=Server.REACH*Server.REACH
end
local function resolveTarget(player,args)
    local x,y,z=tonumber(args.x),tonumber(args.y),tonumber(args.z)
    if not x or not y or not z or x~=x or y~=y or z~=z then return nil,"invalid sample coordinates"end
    x,y,z=math.floor(x),math.floor(y),math.floor(z)
    if not closeEnough(player,x,y,z)then return nil,"water source out of reach"end
    local cell=type(getCell)=="function"and getCell()or nil;local square=call(cell,"getGridSquare",x,y,z)
    if not square then return nil,"water-source square unavailable"end
    local found=nil
    if args.targetKind=="worldItem"then
        if not valid(args.itemId,Commands.MAX_ITEM_ID)or not valid(args.itemType,128)then return nil,"invalid world-item identity"end
        each(call(square,"getWorldObjects"),function(object)
            local item=call(object,"getItem")
            if item and tostring(call(item,"getID"))==args.itemId and call(item,"getFullType")==args.itemType then found=object;return false end
        end)
    elseif args.targetKind=="object"then
        local index=tonumber(args.objectIndex)
        if not index or index~=math.floor(index)or index<0 or index>2048 or not valid(args.spriteName,128)then
            return nil,"invalid water-object identity"
        end
        each(call(square,"getObjects"),function(object)
            if tonumber((call(object,"getObjectIndex")))==index and call(object,"getSpriteName")==args.spriteName then found=object;return false end
        end)
    else return nil,"unsupported sample target"end
    if not found or not waterWorks.getContainer(found)then return nil,"water source unavailable"end
    return found
end
local function findKit(player,itemId)
    if not valid(itemId,Commands.MAX_ITEM_ID)then return nil,"valid test-kit id required"end
    local root=call(player,"getInventory");if not root then return nil,"inventory unavailable"end
    local queue={root};local head,visited=1,0
    while head<=#queue and visited<Sampling.MAX_ITEMS do
        local container=queue[head];head=head+1;local found=nil
        each(call(container,"getItems"),function(item)
            visited=visited+1;if visited>Sampling.MAX_ITEMS then return false end
            if tostring(call(item,"getID"))==itemId and call(item,"getFullType")==Sampling.KIT_TYPE
                and call(item,"getContainer")==container then found=item;return false end
            local nested=call(item,"getInventory");if nested then queue[#queue+1]=nested end
        end,Sampling.MAX_ITEMS)
        if found then return found,container end
    end
    return nil,visited>=Sampling.MAX_ITEMS and"inventory search budget exceeded"or"water test kit not found"
end
local function consumeKit(player,itemId)
    local item,container=findKit(player,itemId);if not item then return false,container end
    local before,delta=tonumber((call(item,"getCurrentUsesFloat"))),tonumber((call(item,"getUseDelta")))
    if not before or not delta or delta<=0 or before+0.0001<delta then return false,"water test kit is empty"end
    local present=call(container,"contains",item);if present~=true then return false,"water test kit ownership changed"end
    local used,called=call(item,"Use");if not called or used==false then return false,"water test reagent use failed"end
    local remains,checked=call(container,"contains",item)
    if checked and remains==true then
        local after=tonumber((call(item,"getCurrentUsesFloat")));local expected=math.max(0,before-delta)
        if not after or math.abs(after-expected)>.0002 then return false,"water test reagent result uncertain"end
        if type(sendItemStats)=="function"then pcall(sendItemStats,item)end
        return true,{kitId=itemId,remaining=after}
    end
    if checked and remains==false and before<=delta+.0002 then
        if type(sendRemoveItemFromContainer)=="function"then pcall(sendRemoveItemFromContainer,container,item)end
        return true,{kitId=itemId,remaining=0,depleted=true}
    end
    return false,"water test reagent result uncertain"
end
local function cacheFor(player)
    local cache=caches[player];if not cache then cache={map={},order={}};caches[player]=cache end;return cache
end
local function remember(player,id,payload)
    local cache=cacheFor(player);cache.map[id]=payload;cache.order[#cache.order+1]=id
    while#cache.order>Server.MAX_CACHE do local old=table.remove(cache.order,1);cache.map[old]=nil end
end
local function reply(player,payload)
    if type(sendServerCommand)~="function"then return false end
    return pcall(sendServerCommand,player,Commands.MODULE,Commands.SAMPLE_RESULT,payload)
end
local function outcome(requestId,ok,value)
    local reason,report
    if ok then report=Sampling.sanitize(value)else reason=tostring(value or"sampling failed"):sub(1,160)end
    return{schemaVersion=1,requestId=requestId,ok=ok==true,reason=reason,report=report}
end
function Server.handle(module,command,player,args)
    if module~=Commands.MODULE or command~=Commands.SAMPLE then return nil,"unhandled command"end
    if not player or type(args)~="table"or not valid(args.requestId,Commands.MAX_REQUEST_ID)
        or(args.mode~="inspect"and args.mode~="kit")then return false,"invalid sampling request"end
    local cache=cacheFor(player);local prior=cache.map[args.requestId]
    if prior then reply(player,prior);return prior.ok,prior end
    if not Sampling.isEnabled()then
        local disabled=outcome(args.requestId,false,"water sampling disabled")
        remember(player,args.requestId,disabled);reply(player,disabled);return false,disabled
    end
    local remaining=allowances[player];if remaining==nil then remaining=Server.MAX_REQUESTS_PER_TICK end
    if remaining<=0 then local value=outcome(args.requestId,false,"rate limited");remember(player,args.requestId,value);reply(player,value);return false,value end
    allowances[player]=remaining-1
    local target,err=resolveTarget(player,args);local report=nil
    if target then report,err=Sampling.describe(target,args.mode)end
    if report and args.mode=="kit"then
        local consumed,consumeResult=consumeKit(player,args.kitId);if not consumed then report=nil;err=consumeResult end
    end
    local value=outcome(args.requestId,report~=nil,report or err);remember(player,args.requestId,value);reply(player,value)
    return value.ok,value
end
function Server.refill()allowances=setmetatable({},{__mode="k"})end
local function onCommand(module,command,player,args)
    local ok,err=pcall(Server.handle,module,command,player,args)
    if not ok and print then print("[B47ANCEDWaterworks] Sampling command failed safely: "..tostring(err))end
end
if Events and Events.OnClientCommand then Events.OnClientCommand.Add(onCommand)end
if Events and Events.OnTick then Events.OnTick.Add(Server.refill)end
waterWorks.SamplingServer=Server
return Server
