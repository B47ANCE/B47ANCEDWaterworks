waterWorks={normalizeQuality=function(value)value=value or{};return{biological=tonumber(value.biological)or 0,
    particulate=tonumber(value.particulate)or 0,chemical=tonumber(value.chemical)or 0,salinity=tonumber(value.salinity)or 0,
    turbidity=tonumber(value.turbidity)or 0,treatment=tostring(value.treatment or"untreated")}end};_G.waterWorks=waterWorks
local filters=dofile(arg[1])
local registered=assert(filters.register{id="fixture.sediment",owner="fixture",capacity=100,flowRestriction=.1,
    replaceableMedia=true,contaminantsRemoved={particulate=true,turbidity=true},evaluate=function(quality,amount,state)
        local fraction=math.min(1,state.remainingCapacity/amount);quality.particulate=quality.particulate*(1-.5*fraction)
        quality.turbidity=quality.turbidity*(1-.75*fraction)
        return{quality=quality,capacityUsed=math.min(amount,state.remainingCapacity),flowMultiplier=.9}end})
assert(registered.evaluate==nil and registered.contaminantsRemoved.particulate);registered.contaminantsRemoved.particulate=nil
local knownFilter,knownError=filters.get("fixture.sediment")
assert(knownFilter.contaminantsRemoved.particulate and knownError==nil,"known definitions must not return an error")
local result=assert(filters.evaluate("fixture.sediment",{biological=.8,particulate=.8,turbidity=.4},10,{remainingCapacity=25,condition=.9}))
assert(result.quality.biological==.8 and result.quality.particulate==.4 and result.quality.turbidity==.1)
assert(result.capacityUsed==10 and result.remainingCapacity==15 and result.flowMultiplier==.9 and not result.exhausted)
assert(filters.register{id="fixture.bad",owner="fixture",capacity=1,flowRestriction=0,contaminantsRemoved={particulate=true},
    evaluate=function(q)q.chemical=.2;return{quality=q,capacityUsed=0,flowMultiplier=1}end})
assert(filters.evaluate("fixture.bad",{particulate=.5},1,{remainingCapacity=1,condition=1})==nil)
assert(filters.register{id="fixture.throw",owner="fixture",capacity=1,flowRestriction=0,contaminantsRemoved={biological=true},
    evaluate=function()error("expected")end})
assert(filters.evaluate("fixture.throw",{},1,{remainingCapacity=1,condition=1})==nil)
assert(filters.evaluate("fixture.sediment",{},1,{remainingCapacity=101,condition=1})==nil)
local missingFilter,missingError=filters.get("missing")
assert(missingFilter==nil and missingError=="unknown filter definition"and#filters.list()==3)
local chain=assert(filters.evaluateChain({
    {id="fixture.sediment",state={remainingCapacity=25,condition=.9},context={name="first"}},
    {filterId="fixture.sediment",filterState={remainingCapacity=10,condition=.8}},
},{biological=.8,particulate=.8,turbidity=.4},5,{requestId="chain"}))
assert(chain.stageCount==2 and chain.amount==5 and#chain.stages==2)
assert(chain.quality.biological==.8 and chain.quality.particulate==.2 and chain.quality.turbidity==.025)
assert(chain.stages[1].remainingCapacity==20 and chain.stages[2].remainingCapacity==5)
chain.stages[1].definition.contaminantsRemoved.particulate=nil
assert(filters.get("fixture.sediment").contaminantsRemoved.particulate,"chain results must be protected")
assert(filters.evaluateChain({}, {},1)==nil)
local tooMany={};for index=1,filters.MAX_CHAIN_STAGES+1 do tooMany[index]={id="fixture.sediment",state={remainingCapacity=1,condition=1}}end
assert(filters.evaluateChain(tooMany,{},1)==nil)
local failed,reason=filters.evaluateChain({{id="fixture.throw",state={remainingCapacity=1,condition=1}}},{},1)
assert(failed==nil and reason:find("filter stage 1 failed",1,true))
assert(filters.evaluateChain({[1]={id="fixture.sediment",state={remainingCapacity=1,condition=1}},[3]={}}, {},1)==nil)
assert(filters.evaluateChain({{id="fixture.sediment",state={remainingCapacity=1,condition=1}},note=true}, {},1)==nil)
print("B47ANCEDWaterworks protected filter-definition and evaluation contract passed")
