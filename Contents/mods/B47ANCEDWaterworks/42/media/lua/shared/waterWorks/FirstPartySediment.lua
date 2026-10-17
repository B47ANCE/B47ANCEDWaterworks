local waterWorks=rawget(_G,"waterWorks") or require "waterWorks/API"
local Registry=require "waterWorks/Registry"
local Infrastructure=require "waterWorks/Infrastructure"
local Filters=require "waterWorks/Filters"
local Transactions=require "waterWorks/FilterTransactions"
local Flow=require "waterWorks/Flow"
local H={HOUSING_TYPE="waterWorks.SedimentFilterHousing",MEDIA_TYPE="waterWorks.SedimentFilterMedia",
    FILTER_ID="waterWorks.sediment",PROVIDER_ID="waterWorks.sedimentHousing",MEDIA_PROVIDER="waterWorks.sedimentMedia",
    ITEM_KEY="waterWorksSedimentIdentity.v1",WORLD_KEY="waterWorksSedimentView.v1",STORE_KEY="sedimentHousings",
    MAX_CAPACITY=10000,MAX_HOUSINGS=4096,MAX_ITEMS=512,MAX_HISTORY=64}
local bindings=setmetatable({},{__mode="v"})
local permit={}
local running=nil
local function authority()return not(type(isClient)=="function" and isClient()==true)end
local function call(object,name,...)
    local ok,fn=pcall(function()return object and object[name]end)
    if not ok or type(fn)~="function"then return nil,false end
    local called,value=pcall(fn,object,...);if called then return value,true end;return nil,false
end
local function finite(value)return type(value)=="number"and value==value and value~=math.huge and value~=-math.huge end
local function validOperation(value)
    return type(value)=="string"and value~=""and #value<=128 and value:match("^[%w_.:%-]+$")~=nil
end
local function data(object)local value=call(object,"getModData");return type(value)=="table"and value or nil end
local function item(object)return call(object,"getItem")end
local function point(object)
    local x,y,z=call(object,"getX"),call(object,"getY"),call(object,"getZ")
    if not finite(x)or not finite(y)or not finite(z)then return nil end
    return{x=math.floor(x),y=math.floor(y),z=math.floor(z)}
end
local function samePlace(a,b)return a and b and a.x==b.x and a.y==b.y and a.z==b.z end
local function near(actor,position)
    local p=point(actor)
    return p and position and call(actor,"isDead")==false and p.z==position.z
        and (p.x-position.x)^2+(p.y-position.y)^2<=9
end
function H.settings()
    local root=rawget(_G,"SandboxVars");local values=type(root)=="table"and root.waterWorks or nil
    values=type(values)=="table"and values or{}
    local function number(key,default,minimum,maximum)
        local value=values[key];if not finite(value)then return default end
        return math.max(minimum,math.min(maximum,value))
    end
    return{enabled=values.EnableSedimentFilters~=false,capacity=number("SedimentMediaCapacity",100,1,H.MAX_CAPACITY),
        removal=number("SedimentRemovalFraction",.75,0,1),time=number("SedimentActionTimeMultiplier",1,.1,10)}
end
local function ledger(store,create)
    if type(store)~="table"or store.schemaVersion~=1 then return nil,"unsupported registry schema"end
    local value=store[H.STORE_KEY]
    if value==nil and create then value={schemaVersion=1,nextId=1,count=0,entries={}};store[H.STORE_KEY]=value end
    if type(value)~="table"or value.schemaVersion~=1 or type(value.entries)~="table"
        or not finite(value.nextId)or value.nextId%1~=0 or value.nextId<1 or value.nextId>2147483647
        or not finite(value.count)or value.count%1~=0 or value.count<0 or value.count>H.MAX_HOUSINGS then return nil,"unsupported sediment ledger"end
    return value
end
local function valid(record)
    return type(record)=="table"and record.schemaVersion==1 and type(record.key)=="string"
        and type(record.nodeId)=="string"and type(record.itemId)=="string"and record.networkId=="WATER"
        and finite(record.x)and finite(record.y)and finite(record.z)
        and finite(record.capacity)and record.capacity>=0 and record.capacity<=H.MAX_CAPACITY
        and finite(record.remaining)and record.remaining>=0 and record.remaining<=record.capacity
        and finite(record.generation)and record.generation%1==0 and record.generation>=0 and record.generation<2147483647
        and type(record.done)=="table"and type(record.order)=="table"and #record.order<=H.MAX_HISTORY
        and(record.pending==nil or type(record.pending)=="table"and record.pending.schemaVersion==1)
end
local function recordFor(store,object)
    local owned=item(object);local md=owned and data(owned);local identity=md and md[H.ITEM_KEY]
    local values=ledger(store,false)
    local record=type(identity)=="table"and identity.schemaVersion==1 and values and values.entries[identity.key]
    if not valid(record)or tostring(call(owned,"getID"))~=record.itemId then return nil,"housing identity/state unavailable"end
    return record
end
local function stageId(record)return record.nodeId..":"..tostring(record.generation)end
local function view(record)
    return{schemaVersion=1,key=record.key,nodeId=record.nodeId,networkId=record.networkId,
        x=record.x,y=record.y,z=record.z,generation=record.generation,capacity=record.capacity,
        remaining=record.remaining,hasMedia=record.generation>0,recovery=record.pending~=nil}
end
local function publish(record,object)
    local md=data(object);if md then md[H.WORLD_KEY]=view(record);call(object,"transmitModData")end
    bindings[stageId(record)]=object
end
function H.presentation(object)
    local md=data(object);local value=md and md[H.WORLD_KEY]
    if type(value)~="table"or value.schemaVersion~=1 or not samePlace(value,point(object))then return nil end
    return value
end
local function resolve(store,nodeId,actor)
    local index=type(store)=="table"and store.nodeIndex and store.nodeIndex[nodeId]
    if not index or index.providerId~=H.PROVIDER_ID then return nil,nil,"sediment housing unavailable"end
    local object=Registry.getRuntimeObject(store,nodeId);local record=object and recordFor(store,object)
    if not record or record.nodeId~=nodeId or not samePlace(record,point(object))then return nil,nil,"housing not loaded at registered location"end
    if not near(actor,record)then return nil,nil,"housing out of reach or actor unavailable"end
    return record,object
end
local function replay(record,operationId,fingerprint)
    local old=record.done[operationId]
    if old then
        if old.fingerprint~=fingerprint then return false,"sediment operation identity conflict"end
        return true,old.result
    end
end
local function finish(record,object,operationId,fingerprint)
    record.pending=nil
    local result={nodeId=record.nodeId,networkId=record.networkId,sediment=view(record)}
    record.done[operationId]={fingerprint=fingerprint,result=result};record.order[#record.order+1]=operationId
    while#record.order>H.MAX_HISTORY do record.done[table.remove(record.order,1)]=nil end
    publish(record,object);return true,result
end
function H.claim(store,object,actor)
    if not authority()then return false,"non-authority"end
    if not H.settings().enabled then return false,"sediment filters disabled"end
    local owned=item(object);local position=point(object);local md=owned and data(owned)
    if not owned or call(owned,"getFullType")~=H.HOUSING_TYPE or not md or call(owned,"getID")==nil
        or not near(actor,position)then return false,"valid nearby housing required"end
    local values,err=ledger(store,true);if not values then return false,err end
    local identity=md[H.ITEM_KEY];local record
    if identity~=nil then
        record=recordFor(store,object);if not record then return false,"unsupported housing identity/state"end
        if record.pending then return false,"housing recovery inspection required"end
        local prior=Registry.getRuntimeObject(store,record.nodeId)
        if prior and prior~=object then return false,"housing already attached to another object"end
        if not samePlace(record,position)and store.nodeIndex[record.nodeId]then
            local removed,reason=Registry.decommissionNode(store,record.nodeId);if not removed then return false,reason end
        end
    else
        if values.count>=H.MAX_HOUSINGS or values.nextId>=2147483647 then return false,"sediment housing registry full"end
        local key="h"..tostring(values.nextId)
        if values.entries[key]~=nil then return false,"sediment identity sequence conflict"end
        values.nextId=values.nextId+1
        record={schemaVersion=1,key=key,nodeId=H.PROVIDER_ID..":"..key,itemId=tostring(call(owned,"getID")),
            networkId="WATER",generation=0,capacity=0,remaining=0,done={},order={}}
        values.entries[key]=record;values.count=values.count+1;md[H.ITEM_KEY]={schemaVersion=1,key=key}
    end
    record.x,record.y,record.z=position.x,position.y,position.z
    local ok,result=Registry.attachObject(store,object)
    if not ok then return false,result end
    publish(record,object);return true,{nodeId=result.nodeId,networkId=result.networkId,sediment=view(record)}
end
-- Bounded owned-inventory search; never trust an object or container supplied by a client.
function H.findMedia(actor,wantedId)
    local root=call(actor,"getInventory");if not root then return nil,"inventory unavailable"end
    local queue,seen={root},{};local head,visited=1,0
    while head<=#queue and visited<H.MAX_ITEMS do
        local container=queue[head];head=head+1
        if not seen[container]then
            seen[container]=true;local items=call(container,"getItems");local size=call(items,"size")
            local n=type(items)=="table"and #items or tonumber(size)or 0
            for i=1,math.min(n,H.MAX_ITEMS-visited)do
                local entry=type(items)=="table"and items[i]or call(items,"get",i-1);visited=visited+1
                if entry and call(entry,"getContainer")==container then
                    local id=call(entry,"getID")
                    if id~=nil and call(entry,"getFullType")==H.MEDIA_TYPE and(wantedId==nil or tostring(id)==wantedId)then return entry,container end
                    local nested=call(entry,"getInventory");if nested then queue[#queue+1]=nested end
                end
            end
        end
    end
    return nil,visited>=H.MAX_ITEMS and"inventory search budget exceeded"or"owned sediment media not found"
end
function H.replace(store,nodeId,actor,mediaId,operationId,generation)
    if not validOperation(operationId)or not finite(generation)or generation%1~=0 or type(mediaId)~="string"or mediaId=="" then return false,"valid sediment operation required"end
    if not authority()then return false,"non-authority"end
    if not H.settings().enabled then return false,"sediment filters disabled"end
    local record,object,err=resolve(store,nodeId,actor);if not record then return false,err end
    local signature="replace:"..tostring(mediaId)..":"..tostring(generation)
    local old,result=replay(record,operationId,signature);if old~=nil then return old,result end
    if record.pending then return false,"housing recovery inspection required"end
    if generation~=record.generation or record.generation>=2147483646 then return false,"sediment media generation changed"end
    local media,container=H.findMedia(actor,mediaId);if not media then return false,container end
    if call(container,"contains",media)~=true or type(sendRemoveItemFromContainer)~="function"then return false,"verified media removal unavailable"end
    record.pending={schemaVersion=1,kind="replace",operationId=operationId,mediaId=mediaId,status="removing"}
    publish(record,object);call(actor,"removeFromHands",media);call(container,"Remove",media)
    local remains,checked=call(container,"contains",media)
    if checked and remains==true then record.pending=nil;publish(record,object);return false,"media removal rejected"end
    if not checked or remains~=false then record.pending.status="recovery";return false,"media removal outcome uncertain"end
    local sent=pcall(sendRemoveItemFromContainer,container,media)
    if not sent then record.pending.status="recovery";return false,"media removal synchronization uncertain"end
    bindings[stageId(record)]=nil
    record.generation=record.generation+1;record.capacity=H.settings().capacity;record.remaining=record.capacity
    return finish(record,object,operationId,signature)
end
local function equalQuality(a,b)
    if type(a)~="table"or type(b)~="table"then return false end
    for _,axis in ipairs({"biological","particulate","chemical","salinity","turbidity"})do
        if math.abs((tonumber(a[axis])or-1)-(tonumber(b[axis])or-2))>.000001 then return false end
    end
    return a.treatment==b.treatment
end
function H.filter(store,nodeId,targetId,actor,operationId,generation)
    if not validOperation(operationId)or not finite(generation)or generation%1~=0 or type(targetId)~="string"or targetId==nodeId then return false,"valid sediment operation required"end
    if not authority()then return false,"non-authority"end
    if not H.settings().enabled then return false,"sediment filters disabled"end
    local record,object,err=resolve(store,nodeId,actor);if not record then return false,err end
    local signature="filter:"..tostring(targetId)..":"..tostring(generation)
    local old,result=replay(record,operationId,signature);if old~=nil then return old,result end
    if record.pending then return false,"housing recovery inspection required"end
    if generation~=record.generation or record.generation==0 then return false,"sediment media unavailable or changed"end
    local index=store.nodeIndex[targetId];local network=index and store.networks[index.networkId];local target=network and network.nodes[targetId]
    if not target or(target.kind~="storage"and target.kind~="fixture")or not near(actor,target)then return false,"nearby water storage/fixture required"end
    local route,reason=Flow.findOpenPath(store,nodeId,targetId,{allowBatchFilterSource=true})
    if not route then return false,reason end
    local owner=route.target.object;local inspected,inspectErr=waterWorks.inspectContainer(owner)
    if not inspected then return false,inspectErr end
    if inspected.capabilities.waterOnlySource~=true or inspected.amount<=0 then return false,"nonempty water-only container required"end
    local quality=inspected.quality;local settings=H.settings()
    if settings.removal<=0 or quality.particulate<=0 and quality.turbidity<=0 then return false,"no removable sediment"end
    local request={schemaVersion=1,operationId=operationId,amount=inspected.amount,inputQuality=quality,
        stages={{providerId=H.MEDIA_PROVIDER,stageId=stageId(record),filterId=H.FILTER_ID}}}
    running=operationId
    local reserved,status,plan=Transactions.reserve(store,request)
    if not reserved or status~="reserved"then running=nil;return false,status end
    record.pending={schemaVersion=1,kind="filter",operationId=operationId,targetId=targetId,
        amount=inspected.amount,qualityBefore=quality,qualityAfter=plan.result.quality,status="reserved"}
    publish(record,object)
    local committed,commitReason=Transactions.commit(store,operationId)
    if not committed then
        running=nil
        if commitReason=="rolledBack"then record.pending=nil else record.pending.status="recovery"end
        publish(record,object);return false,commitReason
    end
    local called,treated,treatmentResult=pcall(waterWorks.applyTreatment,owner,H.FILTER_ID,{operationId=operationId,_sedimentPermit=permit})
    local after=waterWorks.inspectContainer(owner)
    if called and treated==true and after and after.amount==inspected.amount and equalQuality(after.quality,plan.result.quality)then
        running=nil;return finish(record,object,operationId,signature)
    end
    if after and after.amount==inspected.amount and equalQuality(after.quality,quality)and waterWorks.inspectTreatmentRecovery(owner)==nil then
        local restored=Transactions.rollback(store,operationId)
        if restored then record.pending=nil;running=nil;publish(record,object);return false,"sediment treatment failed; media rollback verified"end
    end
    running=nil;record.pending.status="recovery";publish(record,object)
    return false,"sediment treatment/media recovery inspection required"
end

Filters.register{id=H.FILTER_ID,owner="B47ANCEDWaterworks",capacity=H.MAX_CAPACITY,flowRestriction=0,
    contaminantsRemoved={particulate=true,turbidity=true},replaceableMedia=true,
    evaluate=function(quality,amount,state)
        if amount>state.remainingCapacity then return nil,"insufficient sediment capacity for whole container"end
        local fraction=H.settings().removal
        quality.particulate=quality.particulate*(1-fraction);quality.turbidity=quality.turbidity*(1-fraction);quality.treatment=H.FILTER_ID
        return{quality=quality,capacityUsed=amount,flowMultiplier=1}
    end}
waterWorks.registerTreatment{id=H.FILTER_ID,
    validate=function(_,_,context)return context._sedimentPermit==permit,"sediment housing transaction required"end,
    transform=function(quality)
        local fraction=H.settings().removal;quality.particulate=quality.particulate*(1-fraction)
        quality.turbidity=quality.turbidity*(1-fraction);return quality
    end}
Transactions.registerProvider{id=H.MEDIA_PROVIDER,
    resolve=function(id)
        local object=bindings[id];local record=object and recordFor(Registry.getStore(),object)
        if record and stageId(record)==id and(not record.pending or record.pending.operationId==running)then return object end
    end,
    inspect=function(object)
        local record=recordFor(Registry.getStore(),object)
        if record then return{filterId=H.FILTER_ID,remainingCapacity=record.remaining,condition=1}end
    end,
    apply=function(object,_,to,operationId)
        local record=recordFor(Registry.getStore(),object)
        if not authority()or not record or not record.pending or record.pending.operationId~=running then return false end
        record.remaining=to.remainingCapacity;publish(record,object);return true
    end}
Infrastructure.registerProvider{id=H.PROVIDER_ID,kind="filter",priority=200,
    matches=function(object)return call(item(object),"getFullType")==H.HOUSING_TYPE end,
    describe=function(object)
        local record=recordFor(Registry.getStore(),object)or(not authority()and H.presentation(object))
        if not record or not samePlace(record,point(object))then return nil,"housing requires explicit registration"end
        return{networkId=record.networkId,stableKey=record.key,x=record.x,y=record.y,z=record.z,channel="WATER"}
    end,
    onAttach=function(object)local record=recordFor(Registry.getStore(),object);if record then publish(record,object)end end,
    onDetach=function(object)local record=recordFor(Registry.getStore(),object);if record then bindings[stageId(record)]=nil end end,
    getState=function(object)
        local record=recordFor(Registry.getStore(),object)
        return{available=record~=nil and record.generation>0 and record.remaining>0 and not record.pending,
            enabled=H.settings().enabled,filterId=H.FILTER_ID,batchFilter=true,replaceableMedia=true,
            remainingCapacity=record and record.remaining or 0,filterCapacity=record and record.capacity or 0,
            exhausted=not record or record.remaining<=0,fault=record and record.pending and"sediment recovery required"or""}
    end}
H.recordFor=recordFor
waterWorks.FirstPartySediment=H
return H
