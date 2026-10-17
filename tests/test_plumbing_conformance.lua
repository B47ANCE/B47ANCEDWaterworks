isClient=function()return false end
local api=dofile(arg[1]);dofile(arg[2]);dofile(arg[3]);dofile(arg[4]);local Conformance=dofile(arg[5])
local provider={id="fixture.foreignTank",kind="storage",priority=1,matches=function(object)return object.type=="tank"end,
    describe=function(object)return{networkId="fixture-network",channel="WATER",stableKey=object.id}end,
    getState=function(object)return{amount=object.amount,capacity=object.capacity,quality="declared"}end}
local definition={id="fixture.foreignTank",role="storage",authority="server",
    lifecycle={claim="explicit",unload="detach",removal="decommission"},provider=provider}
local report=Conformance.evaluate(definition,{{object={type="tank",id="tank-1",amount=2,capacity=10},matches=true,stableKey="tank-1"},
    {object={type="other",id="other"},matches=false}})
assert(report.status=="passed"and report.checked==2 and report.matched==1)
local fixtures={{object={type="tank",id="tank-1",amount=2,capacity=10},matches=true},
    {object={type="other",id="other"},matches=false}}
local ok,result=Conformance.register(definition,fixtures)
assert(ok and not result.duplicate)
assert(Conformance.register(definition,fixtures))
local positiveOnly=Conformance.evaluate(definition,{{object={type="tank",id="tank-2",amount=1,capacity=2},matches=true}})
assert(positiveOnly.status=="failed"and positiveOnly.rejected==0,"registration evidence must include an exclusion fixture")
local broad={id="fixture.broad",role="storage",authority="server",lifecycle=definition.lifecycle,provider={id="fixture.broad",kind="storage",
    matches=function()return true end,describe=function()return{networkId="n",channel="WATER",stableKey="same"}end,getState=function()return{amount=1,capacity=2}end}}
report=Conformance.evaluate(broad,{{object={},matches=false}});assert(report.status=="failed","broad claiming and missing quality must fail")
local unstable={id="fixture.unstable",role="fixture",authority="server",lifecycle=definition.lifecycle,provider={id="fixture.unstable",kind="fixture",
    matches=function()return true end,describe=function()return{networkId="n",channel="WATER",stableKey=tostring(math.random())}end,getState=function()return{demand=1}end}}
report=Conformance.evaluate(unstable,{{object={},matches=true},{object={other=true},matches=false}});assert(report.status=="failed","unstable identity must fail")
local wrongLifecycle={id="fixture.scan",role="source",authority="client",lifecycle={claim="scan"},provider={id="fixture.scan",kind="source",
    matches=function()return true end,describe=function()return{networkId="n",channel="WATER",stableKey="x"}end,getState=function()return{supply=1,quality="q"}end}}
assert(Conformance.evaluate(wrongLifecycle,{{object={},matches=true},{object={other=true},matches=false}}).status=="failed")
print("B47ANCEDWaterworks explicit foreign-plumbing conformance checks passed")
