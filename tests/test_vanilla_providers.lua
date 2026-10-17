isClient=function() return false end
local api=dofile(arg[1])
local network=dofile(arg[2])
local registry=dofile(arg[3])
local infrastructure=dofile(arg[4])
local vanilla=dofile(arg[5])
local function object(options)
    options=options or {}; local data={}
    local container={amount=options.amount or 5,capacity=options.capacity or 10,rain=options.rain or 0}
    function container:getAmount() return self.amount end
    function container:getCapacity() return self.capacity end
    function container:getRainCatcher() return self.rain end
    function container:isWaterSource() return options.source==true end
    function container:isInputLocked() return false end
    function container:isTaintedWater() return false end
    local value={data=data,container=container}
    function value:getFluidContainer() return self.container end
    function value:getModData() return self.data end
    function value:getX() return 100 end; function value:getY() return 200 end; function value:getZ() return 0 end
    function value:getSpriteName() return "fixtures_sink_01" end
    function value:getObjectIndex() return 3 end
    function value:getUsesExternalWaterSource() return options.fixture==true end
    function value:transmitModData() self.transmitted=true end
    return value
end
local store=registry.newStore(); assert(registry.attachStore(store))
local sink=object({fixture=true})
local ok,result=vanilla.claimObject(store,sink,"house")
assert(ok and result.created and sink.transmitted)
local claim=assert(vanilla.inspectClaim(sink)); assert(claim.kind=="fixture" and claim.networkId=="house")
local state=assert(infrastructure.inspectNode(store,result.nodeId))
assert(state.kind=="fixture" and state.amount==5 and state.capacity==10)
assert(vanilla.claimObject(store,sink,"house")==false,"duplicate claim must fail")
assert(registry.detachObject(store,sink))
local reload=object({fixture=true}); reload.data[vanilla.MARKER_KEY]=sink.data[vanilla.MARKER_KEY]
local reattached,reloadResult=vanilla.reattachClaimedObject(store,reload)
assert(reattached and not reloadResult.created and registry.getRuntimeObject(store,result.nodeId)==reload)
local collector=object({rain=1})
local sourceOk,sourceResult=vanilla.claimObject(store,collector,"yard")
assert(sourceOk and infrastructure.inspectNode(store,sourceResult.nodeId).kind=="source")
isClient=function() return true end
assert(vanilla.claimObject(store,object({}),"client")==false)
print("B47ANCEDWaterworks explicit vanilla FluidContainer provider checks passed")
