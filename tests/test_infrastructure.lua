isClient=function() return false end
local api=dofile(arg[1])
local network=dofile(arg[2])
local registry=dofile(arg[3])
local infrastructure=dofile(arg[4])
local actionCalls=0
infrastructure.registerProvider({id="test.valve",kind="valve",
    matches=function(object) return object.valve==true end,
    describe=function(object) return {networkId="house",stableKey=object.key,channel="WATER"} end,
    getState=function(object) return {open=object.open,pressure=object.pressure,capacity=-4} end,
    validateAction=function(object,action,payload)
        if action~="set-open" or type(payload.open)~="boolean" then return false,"unsupported action" end
        return true
    end,
    performAction=function(object,action,payload) actionCalls=actionCalls+1; object.open=payload.open; return true end})
local store=registry.newStore(); assert(registry.attachStore(store))
local valve={valve=true,key="1:1:0",open=false,pressure=12}
local ok,attached=registry.attachObject(store,valve); assert(ok)
local state=assert(infrastructure.inspectNode(store,attached.nodeId))
assert(state.kind=="valve" and state.open==false and state.pressure==12 and state.capacity==0)
assert(infrastructure.requestAction(store,attached.nodeId,"missing",{})==false)
assert(actionCalls==0)
local changed,result=infrastructure.requestAction(store,attached.nodeId,"set-open",{open=true})
assert(changed and result.open==true and actionCalls==1)
registry.detachObject(store,valve)
assert(infrastructure.inspectNode(store,attached.nodeId)==nil,"unloaded node must not expose stale runtime state")
isClient=function() return true end
assert(infrastructure.requestAction(store,attached.nodeId,"set-open",{open=false})==false)
isClient=function() return false end
local kinds=infrastructure.getKinds(); assert(#kinds>=6)
local hasFilter=false;for _,kind in ipairs(kinds)do if kind=="filter"then hasFilter=true end end;assert(hasFilter)
infrastructure.registerProvider({id="test.filter",kind="filter",
    matches=function(object)return object.filter==true end,
    describe=function(object)return{networkId="house",stableKey=object.key,channel="WATER"}end,
    getState=function(object)return{filterId="fixture.sediment",remainingCapacity=object.remaining,
        filterCapacity=100,condition=.75,flowMultiplier=1.4,replaceableMedia=true}end})
local filter={filter=true,key="filter:1",remaining=25}
local filterOk,filterNode=registry.attachObject(store,filter);assert(filterOk)
local filterState=assert(infrastructure.inspectNode(store,filterNode.nodeId))
assert(filterState.kind=="filter"and filterState.filterId=="fixture.sediment")
assert(filterState.remainingCapacity==25 and filterState.filterCapacity==100 and filterState.condition==.75)
assert(filterState.flowMultiplier==1 and filterState.replaceableMedia==true and filterState.exhausted==false)
filter.remaining=0;filterState=assert(infrastructure.inspectNode(store,filterNode.nodeId));assert(filterState.exhausted==true)
print("B47ANCEDWaterworks semantic infrastructure provider checks passed")
