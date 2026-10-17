local waterWorks=rawget(_G,"waterWorks") or {}
waterWorks.VERSION="0.34.1"
waterWorks.MOD_ID="B47ANCEDWaterworks"
waterWorks.DISPLAY_NAME="B47ANCE’d Waterworks"
waterWorks.Adapters=waterWorks.Adapters or {}
waterWorks.QualityProviders=waterWorks.QualityProviders or {}
waterWorks.Treatments=waterWorks.Treatments or {}
local QUALITY_KEY="waterWorksQuality"
local TRANSFER_RECOVERY_KEY="waterWorksTransferRecovery"
local TREATMENT_RECOVERY_KEY="waterWorksTreatmentRecovery"
local DRAIN_RECOVERY_KEY="waterWorksDrainRecovery"
local transferLocks=setmetatable({},{__mode="k"})
local drainLocks=setmetatable({},{__mode="k"})
local operationCounter=0
local treatmentCounter=0
local drainCounter=0

function waterWorks.isFeatureEnabled(name)
    local root=rawget(_G,"SandboxVars")
    local values=type(root)=="table"and root.waterWorks or nil
    return not(type(values)=="table"and values[name]==false)
end

local function clamp(value) return math.max(0,math.min(1,tonumber(value) or 0)) end
local function call(object,method,...)
    if not object then return false,nil end
    local ok,fn=pcall(function() return object[method] end)
    if not ok or type(fn)~="function" then return false,nil end
    return pcall(fn,object,...)
end
local function copy(value)
    if type(value)~="table" then return value end
    local result={}; for key,entry in pairs(value) do result[key]=copy(entry) end; return result
end
local function modData(owner)
    local ok,data=call(owner,"getModData")
    return ok and type(data)=="table" and data or nil
end
local function authoritative()
    return not (type(isClient)=="function" and isClient()==true)
end
local function finite(value) return type(value)=="number" and value==value and value~=math.huge and value~=-math.huge end
local function amount(adapter)
    local value=adapter and adapter:getAmount() or nil
    return finite(value) and value or nil
end
local function close(a,b) return finite(a) and finite(b) and math.abs(a-b)<=0.0001 end
local function qualityEqual(a,b)
    a=waterWorks.normalizeQuality(a); b=waterWorks.normalizeQuality(b)
    if a.treatment~=b.treatment then return false end
    for _,key in ipairs({"biological","particulate","chemical","salinity","turbidity"}) do
        if not close(a[key],b[key]) then return false end
    end
    return true
end
local function nextOperationId(options)
    if type(options)=="table" and type(options.operationId)=="string" and options.operationId~="" then
        return options.operationId
    end
    operationCounter=operationCounter+1
    return "waterWorks.transfer:"..tostring(operationCounter)
end
local function nativeTransfer(source,target,value)
    local fluidContainerClass=rawget(_G,"FluidContainer")
    if source.container and target.container and fluidContainerClass
        and fluidContainerClass.CanTransfer and fluidContainerClass.Transfer then
        local ok,allowed=pcall(fluidContainerClass.CanTransfer,source.container,target.container)
        if not ok or allowed~=true then return false,"vanilla transfer rejected" end
        local called,result=pcall(fluidContainerClass.Transfer,source.container,target.container,value)
        if not called or result==false then return false,"transfer failed" end
        return true
    elseif target.owner and target.owner.transferFluidFrom and source.container then
        local called,result=pcall(function() return target.owner:transferFluidFrom(source.container,value) end)
        return called and result~=false,called and "transfer rejected" or "transfer failed"
    elseif source.owner and source.owner.transferFluidTo and target.container then
        local called,result=pcall(function() return source.owner:transferFluidTo(target.container,value) end)
        return called and result~=false,called and "transfer rejected" or "transfer failed"
    end
    return false,"no verified transfer primitive"
end
local function quarantine(source,target,record)
    record=copy(record)
    record.schemaVersion=1; record.requiresInspection=true
    local sourceData=modData(source.owner); local targetData=modData(target.owner)
    if sourceData then sourceData[TRANSFER_RECOVERY_KEY]=copy(record); sourceData[TRANSFER_RECOVERY_KEY].role="source" end
    if targetData then targetData[TRANSFER_RECOVERY_KEY]=copy(record); targetData[TRANSFER_RECOVERY_KEY].role="target" end
    source:sync(); target:sync()
end
local function clearQuarantine(source,target)
    local sourceData=modData(source.owner); local targetData=modData(target.owner)
    if sourceData then sourceData[TRANSFER_RECOVERY_KEY]=nil end
    if targetData then targetData[TRANSFER_RECOVERY_KEY]=nil end
    source:sync(); target:sync()
end

local DEFAULT_QUALITY={biological=0,particulate=0,chemical=0,salinity=0,turbidity=0,treatment="untreated"}
function waterWorks.normalizeQuality(value)
    value=type(value)=="table" and value or {}
    return {schemaVersion=1,biological=clamp(value.biological),particulate=clamp(value.particulate),
        chemical=clamp(value.chemical),salinity=clamp(value.salinity),turbidity=clamp(value.turbidity),
        treatment=tostring(value.treatment or "untreated")}
end
function waterWorks.deriveQualityState(value)
    local q=waterWorks.normalizeQuality(value)
    local worst=math.max(q.biological,q.particulate,q.chemical,q.salinity,q.turbidity)
    if worst>=0.80 then return "SEVERELY_CONTAMINATED",true end
    if worst>=0.45 then return "UNSAFE",true end
    if worst>=0.20 then return "QUESTIONABLE",true end
    return "POTABLE",false
end
function waterWorks.mixQuality(targetQuality,targetAmount,sourceQuality,sourceAmount)
    targetAmount=math.max(0,tonumber(targetAmount) or 0); sourceAmount=math.max(0,tonumber(sourceAmount) or 0)
    local total=targetAmount+sourceAmount
    if total<=0 then return waterWorks.normalizeQuality(DEFAULT_QUALITY) end
    local a,b=waterWorks.normalizeQuality(targetQuality),waterWorks.normalizeQuality(sourceQuality)
    local result={treatment=(sourceAmount>=targetAmount and b.treatment or a.treatment)}
    for _,key in ipairs({"biological","particulate","chemical","salinity","turbidity"}) do
        result[key]=(a[key]*targetAmount+b[key]*sourceAmount)/total
    end
    return waterWorks.normalizeQuality(result)
end

function waterWorks.registerAdapter(definition)
    assert(type(definition)=="table" and type(definition.id)=="string","adapter id required")
    assert(type(definition.matches)=="function" and type(definition.create)=="function","adapter callbacks required")
    assert(not waterWorks.Adapters[definition.id],"duplicate B47ANCEDWaterworks adapter: "..definition.id)
    waterWorks.Adapters[definition.id]=definition
    return definition
end

local function orderedDefinitions(registry)
    local result={}
    for _,definition in pairs(registry) do result[#result+1]=definition end
    table.sort(result,function(a,b)
        local ap,bp=tonumber(a.priority) or 0,tonumber(b.priority) or 0
        return ap==bp and a.id<b.id or ap>bp
    end)
    return result
end

function waterWorks.registerQualityProvider(definition)
    assert(type(definition)=="table" and type(definition.id)=="string","quality provider id required")
    assert(type(definition.matches)=="function" and type(definition.getQuality)=="function","quality provider callbacks required")
    assert(not waterWorks.QualityProviders[definition.id],"duplicate B47ANCEDWaterworks quality provider: "..definition.id)
    waterWorks.QualityProviders[definition.id]=definition
    return definition
end

function waterWorks.inferQuality(owner,adapter)
    adapter=adapter or waterWorks.getContainer(owner)
    for _,provider in ipairs(orderedDefinitions(waterWorks.QualityProviders)) do
        local matchedOk,matched=pcall(provider.matches,owner,adapter)
        if matchedOk and matched then
            local qualityOk,quality=pcall(provider.getQuality,owner,adapter)
            if qualityOk and type(quality)=="table" then
                local normalized=waterWorks.normalizeQuality(quality)
                normalized.providerId=provider.id
                return normalized,provider.id
            end
        end
    end
    return nil
end

function waterWorks.registerTreatment(definition)
    assert(type(definition)=="table" and type(definition.id)=="string","treatment id required")
    assert(type(definition.transform)=="function","treatment transform required")
    assert(not waterWorks.Treatments[definition.id],"duplicate B47ANCEDWaterworks treatment: "..definition.id)
    waterWorks.Treatments[definition.id]=definition
    return definition
end

local function fluidAdapter(owner,container)
    return {
        kind="fluid-container",owner=owner,container=container,
        getAmount=function(self) local ok,v=call(self.container,"getAmount"); return ok and tonumber(v) or 0 end,
        getCapacity=function(self) local ok,v=call(self.container,"getCapacity"); return ok and tonumber(v) or 0 end,
        isTainted=function(self)
            local ok,v=call(self.container,"isTaintedWater"); if ok then return v==true end
            ok,v=call(self.owner,"isTaintedWater"); return ok and v==true or false
        end,
        sync=function(self)
            local ok=call(self.owner,"sync")
            if not ok then call(self.owner,"transmitModData") end
        end,
    }
end
local function legacyAdapter(owner)
    return {
        kind="legacy-water",owner=owner,
        getAmount=function(self) local ok,v=call(self.owner,"getWaterAmount"); return ok and tonumber(v) or 0 end,
        getCapacity=function(self) local ok,v=call(self.owner,"getWaterMax"); return ok and tonumber(v) or 0 end,
        isTainted=function(self) local ok,v=call(self.owner,"isTaintedWater"); return ok and v==true or false end,
        sync=function(self) call(self.owner,"transmitModData") end,
    }
end

function waterWorks.getContainer(owner)
    if not owner then return nil,"owner required" end
    local ok,container=call(owner,"getFluidContainer")
    if ok and container then return fluidAdapter(owner,container) end
    local worldOk,world=call(owner,"getWorldItem")
    if worldOk and world then
        ok,container=call(world,"getFluidContainer")
        if ok and container then return fluidAdapter(world,container) end
    end
    local amountOk=call(owner,"getWaterAmount")
    local maxOk=call(owner,"getWaterMax")
    if amountOk and maxOk then return legacyAdapter(owner) end
    local ordered={}; for id in pairs(waterWorks.Adapters) do ordered[#ordered+1]=id end; table.sort(ordered)
    for _,id in ipairs(ordered) do
        local adapter=waterWorks.Adapters[id]
        local matchedOk,matched=pcall(adapter.matches,owner)
        if matchedOk and matched then
            local createdOk,result=pcall(adapter.create,owner)
            if createdOk and result then result.kind=result.kind or id; return result end
        end
    end
    return nil,"no compatible water container"
end

function waterWorks.inspectContainer(owner)
    local adapter,err=waterWorks.getContainer(owner)
    if not adapter then return nil,err end
    local result={kind=adapter.kind,amount=adapter:getAmount(),capacity=adapter:getCapacity(),
        tainted=adapter:isTainted(),capabilities={}}
    local _,className=call(adapter.owner,"getObjectName")
    result.ownerClass=className and tostring(className) or nil
    local container=adapter.container
    if container then
        local checks={waterSource="isWaterSource",waterOnlySource="isWaterOnlySource",mixture="isMixture",
            inputLocked="isInputLocked",outputLocked="isOutputLocked"}
        for key,method in pairs(checks) do
            local ok,value=call(container,method)
            if ok then result.capabilities[key]=value==true end
        end
        local ok,fluid=call(container,"getPrimaryFluid")
        if ok and fluid then
            local typeOk,typeName=call(fluid,"getFluidTypeString")
            result.primaryFluid=typeOk and tostring(typeName) or tostring(fluid)
        end
    end
    if type(instanceof)=="function" then
        local ok,trough=pcall(instanceof,adapter.owner,"IsoFeedingTrough")
        result.capabilities.feedingTrough=ok and trough==true or false
        local worldOk,worldItem=pcall(instanceof,adapter.owner,"IsoWorldInventoryObject")
        result.capabilities.worldInventory=worldOk and worldItem==true or false
    end
    result.quality=waterWorks.getQuality(owner)
    result.qualityState=waterWorks.deriveQualityState(result.quality)
    return result
end

function waterWorks.getQuality(owner)
    local adapter=waterWorks.getContainer(owner)
    if not adapter then return nil,"not a water container" end
    local data=modData(adapter.owner)
    if data and type(data[QUALITY_KEY])=="table" then return waterWorks.normalizeQuality(data[QUALITY_KEY]) end
    local inferred=waterWorks.inferQuality(owner,adapter)
    if inferred then return inferred end
    local quality=copy(DEFAULT_QUALITY)
    if adapter:isTainted() then quality.biological=0.75; quality.treatment="vanilla-tainted" end
    return waterWorks.normalizeQuality(quality)
end


function waterWorks.previewTreatment(owner,treatmentId,context)
    local definition=waterWorks.Treatments[treatmentId]
    if not definition then return nil,"unknown treatment" end
    local quality,err=waterWorks.getQuality(owner); if not quality then return nil,err end
    if definition.validate then
        local ok,allowed,reason=pcall(definition.validate,owner,copy(quality),context or {})
        if not ok then return nil,"treatment validation error" end
        if allowed~=true then return nil,reason or "treatment rejected" end
    end
    local ok,result=pcall(definition.transform,copy(quality),context or {},owner)
    if not ok or type(result)~="table" then return nil,"treatment transform failed" end
    result=waterWorks.normalizeQuality(result)
    result.treatment=treatmentId
    return result
end

function waterWorks.applyTreatment(owner,treatmentId,context)
    if not authoritative() then return false,"non-authority" end
    context=type(context)=="table" and context or {}
    local adapter,adapterErr=waterWorks.getContainer(owner); if not adapter then return false,adapterErr end
    local data=modData(adapter.owner); if not data then return false,"owner has no modData" end
    if data[DRAIN_RECOVERY_KEY]~=nil then return false,"container has reserved drain" end
    if data[TREATMENT_RECOVERY_KEY]~=nil then return false,"container requires treatment recovery inspection" end
    local before,beforeErr=waterWorks.getQuality(owner); if not before then return false,beforeErr end
    local result,err=waterWorks.previewTreatment(owner,treatmentId,context)
    if not result then return false,err end
    treatmentCounter=treatmentCounter+1
    local operationId=type(context.operationId)=="string" and context.operationId~=""
        and context.operationId or "waterWorks.treatment:"..tostring(treatmentCounter)
    if #operationId>128 or operationId:find("[%c]",1) then return false,"invalid treatment operation id" end
    local historyBefore=copy(type(data.waterWorksTreatmentHistory)=="table" and data.waterWorksTreatmentHistory or {})
    local record={schemaVersion=1,status="executing",operationId=operationId,treatmentId=treatmentId,
        qualityBefore=copy(before),qualityAfter=copy(result),worldAgeHours=context.worldAgeHours}
    data[TREATMENT_RECOVERY_KEY]=record; adapter:sync()
    local called,success,saved=pcall(function()
        local ok,value=waterWorks.setQuality(owner,result); if not ok then return false,value end
        if not qualityEqual(waterWorks.getQuality(owner),result) then return false,"treatment quality readback mismatch" end
        data.waterWorksTreatmentHistory=data.waterWorksTreatmentHistory or {}
        local history=data.waterWorksTreatmentHistory
        history[#history+1]={id=treatmentId,worldAgeHours=context.worldAgeHours,operationId=operationId}
        while #history>16 do table.remove(history,1) end
        adapter:sync()
        return true,value
    end)
    if called and success==true then
        data[TREATMENT_RECOVERY_KEY]=nil; adapter:sync(); return true,saved
    end
    local restored=waterWorks.setQuality(owner,before)==true and qualityEqual(waterWorks.getQuality(owner),before)
    data.waterWorksTreatmentHistory=historyBefore
    if restored then data[TREATMENT_RECOVERY_KEY]=nil
    else record.status="inspection_required"; record.reason=tostring(saved or success) end
    adapter:sync()
    return false,(called and (saved or "treatment transaction failed")) or tostring(success)
end

function waterWorks.inspectTreatmentRecovery(owner)
    local adapter=waterWorks.getContainer(owner); local data=adapter and modData(adapter.owner) or nil
    local record=data and data[TREATMENT_RECOVERY_KEY] or nil
    return type(record)=="table" and copy(record) or nil
end

waterWorks.registerTreatment({id="boiled",transform=function(quality)
    quality.biological=math.min(quality.biological,0.02)
    return quality
end})

function waterWorks.setQuality(owner,quality)
    if not authoritative() then return false,"non-authority" end
    local adapter=waterWorks.getContainer(owner)
    if not adapter then return false,"not a water container" end
    local data=modData(adapter.owner); if not data then return false,"owner has no modData" end
    if data[DRAIN_RECOVERY_KEY]~=nil then return false,"container has reserved drain" end
    local normalized=waterWorks.normalizeQuality(quality)
    data[QUALITY_KEY]=normalized
    local _,tainted=waterWorks.deriveQualityState(normalized)
    call(adapter.owner,"setTaintedWater",tainted)
    adapter:sync()
    return true,normalized
end

function waterWorks.drain(owner,requestedAmount,options)
    if not authoritative() then return false,"non-authority" end
    local adapter,err=waterWorks.getContainer(owner); if not adapter then return false,err end
    if not adapter.container then return false,"no verified fluid drain primitive" end
    local data=modData(adapter.owner); if not data then return false,"owner has no modData" end
    if data[DRAIN_RECOVERY_KEY]~=nil then return false,"container requires drain recovery inspection" end
    if drainLocks[adapter.owner] or transferLocks[adapter.owner] then return false,"container busy" end
    local requested=tonumber(requestedAmount); if not finite(requested) or requested<=0 then return false,"invalid drain amount" end
    local before=amount(adapter); if not before or before<=0 then return false,"nothing drainable" end
    requested=math.min(requested,before); local expected=before-requested
    drainCounter=drainCounter+1
    local operationId=type(options)=="table" and type(options.operationId)=="string" and options.operationId
        or "waterWorks.drain:"..tostring(drainCounter)
    if operationId=="" or #operationId>128 or operationId:find("[%c]",1) then return false,"invalid drain operation id" end
    local record={schemaVersion=1,status="executing",operationId=operationId,amountBefore=before,amountExpected=expected,requested=requested}
    data[DRAIN_RECOVERY_KEY]=record; drainLocks[adapter.owner]=operationId; adapter:sync()
    local called,result=call(adapter.container,"adjustAmount",expected); adapter:sync()
    local after=amount(adapter); local removed=after and before-after or nil
    if called and result~=false and close(after,expected) and removed and removed>0 then
        data[DRAIN_RECOVERY_KEY]=nil; drainLocks[adapter.owner]=nil; adapter:sync()
        return true,{operationId=operationId,amount=removed,amountBefore=before,amountAfter=after}
    end
    call(adapter.container,"adjustAmount",before); adapter:sync()
    local restored=close(amount(adapter),before)
    drainLocks[adapter.owner]=nil
    if restored then data[DRAIN_RECOVERY_KEY]=nil
    else record.status="inspection_required"; record.amountObserved=after; record.reason="drain write or readback failed" end
    adapter:sync()
    return false,restored and "drain failed; rollback verified" or "drain failed; recovery inspection required"
end

function waterWorks.inspectDrainRecovery(owner)
    local adapter=waterWorks.getContainer(owner); local data=adapter and modData(adapter.owner) or nil
    local record=data and data[DRAIN_RECOVERY_KEY] or nil
    return type(record)=="table" and copy(record) or nil
end

local function drainOperationSeen(data,operationId)
    for _,id in ipairs(type(data.waterWorksDrainOperations)=="table"and data.waterWorksDrainOperations or{})do if id==operationId then return true end end
    return false
end
local function rememberDrainOperation(data,operationId)
    local history=type(data.waterWorksDrainOperations)=="table"and data.waterWorksDrainOperations or{};data.waterWorksDrainOperations=history
    history[#history+1]=operationId;while#history>64 do table.remove(history,1)end
end
function waterWorks.beginDrainTransaction(owner,requestedAmount,operationId)
    if not authoritative()then return false,"non-authority"end
    if type(operationId)~="string"or operationId==""or#operationId>128 or operationId:find("[%c]",1)then return false,"invalid drain operation id"end
    local adapter,err=waterWorks.getContainer(owner);if not adapter then return false,err end
    if not adapter.container then return false,"no verified fluid drain primitive"end
    local data=modData(adapter.owner);if not data then return false,"owner has no modData"end
    if drainOperationSeen(data,operationId)then return true,{duplicate=true,operationId=operationId,status="committed"}end
    local existing=data[DRAIN_RECOVERY_KEY]
    if type(existing)=="table"and existing.operationId==operationId and existing.status=="reserved"then
        return true,{duplicate=true,operationId=operationId,amount=existing.requested,status="reserved"}
    end
    if existing~=nil then return false,"container requires drain recovery inspection"end
    if drainLocks[adapter.owner]or transferLocks[adapter.owner]then return false,"container busy"end
    local requested=tonumber(requestedAmount);if not finite(requested)or requested<=0 then return false,"invalid drain amount"end
    local before=amount(adapter);if not before or before+0.000001<requested then return false,"insufficient fluid"end
    local expected=before-requested;local quality=waterWorks.getQuality(owner)
    local record={schemaVersion=1,status="executing",operationId=operationId,amountBefore=before,amountExpected=expected,
        requested=requested,qualityBefore=copy(quality)}
    data[DRAIN_RECOVERY_KEY]=record;drainLocks[adapter.owner]=operationId;adapter:sync()
    local called,result=call(adapter.container,"adjustAmount",expected);adapter:sync()
    if called and result~=false and close(amount(adapter),expected)then
        record.status="reserved";drainLocks[adapter.owner]=nil;adapter:sync()
        return true,{duplicate=false,operationId=operationId,amount=requested,amountAfter=expected,status="reserved"}
    end
    call(adapter.container,"adjustAmount",before);adapter:sync();local restored=close(amount(adapter),before)
    drainLocks[adapter.owner]=nil;if restored then data[DRAIN_RECOVERY_KEY]=nil else record.status="inspection_required";record.reason="drain reservation failed"end
    adapter:sync();return false,restored and"drain reservation failed; rollback verified"or"drain reservation failed; inspection required"
end
function waterWorks.commitDrainTransaction(owner,operationId)
    if not authoritative()then return false,"non-authority"end
    local adapter,err=waterWorks.getContainer(owner);if not adapter then return false,err end
    local data=modData(adapter.owner);if not data then return false,"owner has no modData"end
    if drainOperationSeen(data,operationId)then return true,{duplicate=true,operationId=operationId}end
    local record=data[DRAIN_RECOVERY_KEY]
    if type(record)~="table"or record.operationId~=operationId or record.status~="reserved"then return false,"drain reservation unavailable"end
    if not close(amount(adapter),record.amountExpected)or not qualityEqual(waterWorks.getQuality(owner),record.qualityBefore)then
        record.status="inspection_required";record.reason="reserved drain state changed";adapter:sync();return false,"drain reservation changed; inspection required"
    end
    data[DRAIN_RECOVERY_KEY]=nil;rememberDrainOperation(data,operationId);adapter:sync()
    return true,{duplicate=false,operationId=operationId,amount=record.requested,amountAfter=record.amountExpected}
end
function waterWorks.rollbackDrainTransaction(owner,operationId)
    if not authoritative()then return false,"non-authority"end
    local adapter,err=waterWorks.getContainer(owner);if not adapter then return false,err end
    local data=modData(adapter.owner);local record=data and data[DRAIN_RECOVERY_KEY]
    if type(record)~="table"or record.operationId~=operationId or(record.status~="reserved"and record.status~="executing")then return false,"drain reservation unavailable"end
    call(adapter.container,"adjustAmount",record.amountBefore);adapter:sync()
    local restored=close(amount(adapter),record.amountBefore)and qualityEqual(waterWorks.getQuality(owner),record.qualityBefore)
    if restored then data[DRAIN_RECOVERY_KEY]=nil else record.status="inspection_required";record.reason="drain rollback failed"end
    adapter:sync();return restored,restored and{operationId=operationId,restored=record.amountBefore}or"drain rollback failed; inspection required"
end

function waterWorks.transfer(sourceOwner,targetOwner,requestedAmount,options)
    if not authoritative() then return false,"non-authority" end
    local source,sourceErr=waterWorks.getContainer(sourceOwner); if not source then return false,sourceErr end
    local target,targetErr=waterWorks.getContainer(targetOwner); if not target then return false,targetErr end
    if source.owner==target.owner then return false,"source and target must differ" end
    if transferLocks[source.owner] or transferLocks[target.owner] then return false,"container busy" end
    local sourceData,targetData=modData(source.owner),modData(target.owner)
    if (sourceData and(sourceData[TRANSFER_RECOVERY_KEY]or sourceData[DRAIN_RECOVERY_KEY]))
        or (targetData and(targetData[TRANSFER_RECOVERY_KEY]or targetData[DRAIN_RECOVERY_KEY])) then
        return false,"container requires transfer recovery inspection"
    end
    -- Quality is part of the authoritative transaction. Refuse the transfer
    -- before vanilla mutates either container if its result cannot be saved.
    if not targetData then return false,"target quality state unavailable" end
    local numeric=tonumber(requestedAmount)
    if not finite(numeric) or numeric<=0 then return false,"invalid transfer amount" end
    local sourceBefore,targetBefore=amount(source),amount(target)
    local capacity=target:getCapacity()
    if not sourceBefore or not targetBefore or not finite(capacity) then return false,"container amount unavailable" end
    local requested=math.max(0,math.min(numeric,sourceBefore,math.max(0,capacity-targetBefore)))
    if requested<=0 then return false,"nothing transferable" end
    local sourceQuality=waterWorks.getQuality(sourceOwner)
    local targetQuality=waterWorks.getQuality(targetOwner)
    local operationId=nextOperationId(options)
    transferLocks[source.owner]=operationId; transferLocks[target.owner]=operationId
    local transferred,transferError=nativeTransfer(source,target,requested)
    if not transferred then transferLocks[source.owner]=nil; transferLocks[target.owner]=nil; return false,transferError end
    source:sync(); target:sync()
    local sourceAfter,targetAfter=amount(source),amount(target)
    local sourceDelta=sourceAfter and sourceBefore-sourceAfter or nil
    local targetDelta=targetAfter and targetAfter-targetBefore or nil
    local measured=sourceDelta and targetDelta and close(sourceDelta,targetDelta) and sourceDelta or nil
    local validDelta=measured and measured>0 and measured<=requested+0.0001
    local mixed=validDelta and waterWorks.mixQuality(targetQuality,targetBefore,sourceQuality,measured) or nil
    local qualityOk,qualityErr=false,"transfer delta unverified"
    if validDelta then qualityOk,qualityErr=waterWorks.setQuality(targetOwner,mixed) end
    local saved=targetData[QUALITY_KEY]
    if qualityOk and not qualityEqual(saved,mixed) then qualityOk=false; qualityErr="quality write readback mismatch" end
    if not validDelta or not qualityOk then
        local rollbackAmount=measured or (targetDelta and targetDelta>0 and targetDelta) or nil
        local rolled=false
        if rollbackAmount then
            local reverseOk=nativeTransfer(target,source,rollbackAmount)
            source:sync(); target:sync()
            rolled=reverseOk and close(amount(source),sourceBefore) and close(amount(target),targetBefore)
        end
        if rolled then
            local restored=waterWorks.setQuality(targetOwner,targetQuality)
            rolled=restored==true and qualityEqual(waterWorks.getQuality(targetOwner),targetQuality)
            if rolled then
                transferLocks[source.owner]=nil; transferLocks[target.owner]=nil
                return false,tostring(qualityErr).."; fluid rollback verified"
            end
        end
        quarantine(source,target,{operationId=operationId,sourceBefore=sourceBefore,targetBefore=targetBefore,
            sourceAfter=sourceAfter,targetAfter=targetAfter,requested=requested,measured=measured,
            targetQualityBefore=targetQuality,targetQualityAfter=mixed,reason=tostring(qualityErr)})
        transferLocks[source.owner]=nil; transferLocks[target.owner]=nil
        return false,tostring(qualityErr).."; transfer recovery inspection required"
    end
    transferLocks[source.owner]=nil; transferLocks[target.owner]=nil
    return true,{operationId=operationId,amount=measured,quality=mixed,state=waterWorks.deriveQualityState(mixed)}
end

function waterWorks.inspectTransferRecovery(sourceOwner,targetOwner)
    local source=waterWorks.getContainer(sourceOwner); local target=waterWorks.getContainer(targetOwner)
    if not source or not target then return nil,"two compatible containers required" end
    local sourceRecord=modData(source.owner) and modData(source.owner)[TRANSFER_RECOVERY_KEY]
    local targetRecord=modData(target.owner) and modData(target.owner)[TRANSFER_RECOVERY_KEY]
    if type(sourceRecord)~="table" and type(targetRecord)~="table" then return {status="clear",requiresInspection=false} end
    if type(sourceRecord)~="table" or type(targetRecord)~="table"
        or sourceRecord.operationId~=targetRecord.operationId then
        return {status="manual-inspection",requiresInspection=true,reason="recovery records do not match"}
    end
    local sourceAmount,targetAmount=amount(source),amount(target)
    local status="manual-inspection"
    if close(sourceAmount,sourceRecord.sourceBefore) and close(targetAmount,sourceRecord.targetBefore) then status="rolled-back"
    elseif close(sourceAmount,sourceRecord.sourceAfter) and close(targetAmount,sourceRecord.targetAfter)
        and sourceRecord.targetQualityAfter and qualityEqual(waterWorks.getQuality(targetOwner),sourceRecord.targetQualityAfter) then
        status="committed"
    end
    return {status=status,requiresInspection=true,operationId=sourceRecord.operationId,
        sourceAmount=sourceAmount,targetAmount=targetAmount,record=copy(sourceRecord)}
end

function waterWorks.resolveTransferRecovery(sourceOwner,targetOwner)
    if not authoritative() then return false,"non-authority" end
    local report,err=waterWorks.inspectTransferRecovery(sourceOwner,targetOwner)
    if not report then return false,err end
    if report.requiresInspection~=true then return true,report end
    if report.status~="rolled-back" and report.status~="committed" then return false,report.status,report end
    local source=waterWorks.getContainer(sourceOwner); local target=waterWorks.getContainer(targetOwner)
    clearQuarantine(source,target)
    report.requiresInspection=false; report.resolved=true
    return true,report
end

waterWorks.QUALITY_KEY=QUALITY_KEY
waterWorks.TREATMENT_RECOVERY_KEY=TREATMENT_RECOVERY_KEY
waterWorks.DRAIN_RECOVERY_KEY=DRAIN_RECOVERY_KEY
waterWorks.TRANSFER_RECOVERY_KEY=TRANSFER_RECOVERY_KEY
_G.waterWorks=waterWorks
_G.B47ANCEDWaterworks=waterWorks
require "waterWorks/Filters"
return waterWorks
