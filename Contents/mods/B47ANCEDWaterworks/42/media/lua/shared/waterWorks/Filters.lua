local waterWorks=rawget(_G,"waterWorks") or require "waterWorks/API"
local Filters={API_VERSION="1.1.0",Definitions={},MAX_CHAIN_STAGES=16}
local AXES={biological=true,particulate=true,chemical=true,salinity=true,turbidity=true}
local function finite(value)value=tonumber(value);return value and value==value and value~=math.huge and value~=-math.huge and value or nil end
local function validId(value,maximum)return type(value)=="string"and value~=""and#value<=(maximum or 96)and value:match("^[%w_.:%-]+$")~=nil end
local function copy(value,seen)
    if type(value)~="table"then return value end;seen=seen or{};if seen[value]then return nil end;seen[value]=true
    local result={};for key,entry in pairs(value)do if type(key)=="string"or type(key)=="number"then result[key]=copy(entry,seen)end end
    seen[value]=nil;return result
end
local function view(definition)return{id=definition.id,owner=definition.owner,revision=definition.revision,
    contaminantsRemoved=copy(definition.contaminantsRemoved),capacity=definition.capacity,
    flowRestriction=definition.flowRestriction,replaceableMedia=definition.replaceableMedia,apiVersion=Filters.API_VERSION}end
local function state(value,capacity)
    if type(value)~="table"then return nil,"filter state required"end
    local remaining,condition=finite(value.remainingCapacity),finite(value.condition)
    if not remaining or remaining<0 or remaining>capacity then return nil,"invalid remaining filter capacity"end
    if not condition or condition<0 or condition>1 then return nil,"invalid filter condition"end
    return{remainingCapacity=remaining,condition=condition}
end
function Filters.register(definition)
    assert(type(definition)=="table","filter definition required");assert(validId(definition.id),"filter id required")
    assert(validId(definition.owner),"filter owner required");assert(type(definition.evaluate)=="function","filter evaluation callback required")
    assert(not Filters.Definitions[definition.id],"duplicate filter definition: "..definition.id)
    local capacity=finite(definition.capacity);assert(capacity and capacity>0,"positive filter capacity required")
    local restriction=finite(definition.flowRestriction);assert(restriction and restriction>=0 and restriction<=1,"invalid filter flow restriction")
    local removed,count={},0;for key,value in pairs(definition.contaminantsRemoved or{})do
        assert(AXES[key]and value==true,"invalid removed contaminant axis");removed[key]=true;count=count+1 end
    assert(count>0,"filter must declare at least one removed contaminant")
    local stored={id=definition.id,owner=definition.owner,revision=math.max(1,math.floor(finite(definition.revision)or 1)),
        contaminantsRemoved=removed,capacity=capacity,flowRestriction=restriction,replaceableMedia=definition.replaceableMedia==true,
        evaluate=definition.evaluate};Filters.Definitions[stored.id]=stored;return view(stored)
end
function Filters.get(id)
    local definition=Filters.Definitions[id]
    if not definition then return nil,"unknown filter definition"end
    return view(definition),nil
end
function Filters.list()local result={};for _,definition in pairs(Filters.Definitions)do result[#result+1]=view(definition)end
    table.sort(result,function(a,b)return a.id<b.id end);return result end
function Filters.evaluate(id,inputQuality,amount,filterState,context)
    local definition=Filters.Definitions[id];if not definition then return nil,"unknown filter definition"end
    amount=finite(amount);if not amount or amount<=0 then return nil,"positive finite filter amount required"end
    local normalized,err=state(filterState,definition.capacity);if not normalized then return nil,err end
    local before=waterWorks.normalizeQuality(inputQuality)
    local ok,result,reason=pcall(definition.evaluate,copy(before),amount,copy(normalized),copy(context or{}))
    if not ok or type(result)~="table"then return nil,tostring(ok and reason or result or"filter provider failed"):sub(1,160)end
    local used,flow=finite(result.capacityUsed),finite(result.flowMultiplier)
    if not used or used<0 or used>normalized.remainingCapacity then return nil,"invalid filter capacity use"end
    if not flow or flow<0 or flow>1 then return nil,"invalid filter flow multiplier"end
    local after=waterWorks.normalizeQuality(result.quality)
    for axis in pairs(AXES)do
        if definition.contaminantsRemoved[axis]then if after[axis]>before[axis]then return nil,"filter increased declared contaminant"end
        elseif math.abs(after[axis]-before[axis])>0.000001 then return nil,"filter changed undeclared contaminant"end end
    local remaining=normalized.remainingCapacity-used
    return{definition=view(definition),quality=after,amount=amount,capacityUsed=used,remainingCapacity=remaining,
        condition=normalized.condition,flowMultiplier=flow,exhausted=result.exhausted==true or remaining<=0}
end
function Filters.evaluateChain(stages,inputQuality,amount,context)
    if type(stages)~="table"then return nil,"filter stages required"end
    amount=finite(amount);if not amount or amount<=0 then return nil,"positive finite filter amount required"end
    local count=0
    for key in pairs(stages)do
        if type(key)~="number"or key<1 or key%1~=0 then return nil,"filter stages must be a dense array"end
        count=count+1
        if count>Filters.MAX_CHAIN_STAGES then return nil,"filter chain limit exceeded"end
    end
    if count<1 then return nil,"at least one filter stage required"end
    for index=1,count do if stages[index]==nil then return nil,"filter stages must be a dense array"end end
    local quality=waterWorks.normalizeQuality(inputQuality)
    local results={}
    for index=1,count do
        local stage=stages[index]
        if type(stage)~="table"then return nil,"invalid filter stage "..tostring(index)end
        local id=stage.id or stage.filterId
        local stageContext=copy(context or{})
        if type(stage.context)=="table"then
            for key,value in pairs(stage.context)do stageContext[key]=copy(value)end
        end
        stageContext.stageIndex=index
        local result,err=Filters.evaluate(id,quality,amount,stage.state or stage.filterState,stageContext)
        if not result then return nil,"filter stage "..tostring(index).." failed: "..tostring(err)end
        quality=result.quality
        results[index]=result
    end
    return{quality=copy(quality),amount=amount,stages=copy(results),stageCount=count}
end
waterWorks.Filters=Filters;waterWorks.registerFilterDefinition=Filters.register;waterWorks.getFilterDefinition=Filters.get
waterWorks.listFilterDefinitions=Filters.list;waterWorks.evaluateFilter=Filters.evaluate
waterWorks.evaluateFilterChain=Filters.evaluateChain
_G.waterWorks=waterWorks
return Filters
