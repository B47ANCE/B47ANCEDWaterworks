isClient=function()return false end
local api=dofile(arg[1]);local sampling=dofile(arg[2])
local fluid={amount=8,capacity=10}
function fluid:getAmount()return self.amount end;function fluid:getCapacity()return self.capacity end
function fluid:isTaintedWater()return false end
local object={md={}};function object:getFluidContainer()return fluid end;function object:getModData()return self.md end
function object:transmitModData()end;function object:setTaintedWater(value)self.tainted=value end
assert(api.setQuality(object,{biological=.51,particulate=.24,chemical=.01,salinity=.81,turbidity=.10,treatment="filtered"}))
local visual=assert(sampling.describe(object,"inspect"))
assert(visual.appearance=="SLIGHTLY_CLOUDY"and visual.odor=="STRONG_OR_FOUL_ODOR")
assert(visual.axes==nil and visual.qualityState==nil and visual.treatment==nil,
    "basic inspection must not reveal hidden quality axes")
local tested=assert(sampling.describe(object,"kit"))
assert(tested.axes.biological=="HIGH"and tested.axes.particulate=="MODERATE")
assert(tested.axes.chemical=="NONE"and tested.axes.salinity=="SEVERE"and tested.axes.turbidity=="LOW")
assert(tested.qualityState=="SEVERELY_CONTAMINATED"and tested.treatment=="filtered")
tested.secret=.123;tested.axes.exact=.51
local wire=sampling.sanitize(tested);assert(wire.secret==nil and wire.axes.exact==nil)
fluid.amount=0;assert(sampling.describe(object,"kit")==nil,"empty sources must not produce a sample")
assert(sampling.describe(object,"exact")==nil,"unsupported precision must fail closed")
print("B47ANCEDWaterworks tiered water-sampling semantics passed")
