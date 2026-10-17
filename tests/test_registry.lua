isClient=function() return false end
local network=dofile(arg[1])
local registry=dofile(arg[2])
registry.registerProvider({id="test.fixture",priority=10,
    matches=function(object) return object.fixture==true end,
    describe=function(object) return {networkId=object.system or "house",stableKey=object.key,
        kind="fixture",channel="WATER",x=object.x,y=object.y,z=object.z} end})
registry.registerProvider({id="test.broken",priority=20,
    matches=function() error("broken classifier") end,
    describe=function() error("unreachable") end})
local store={}; assert(registry.attachStore(store)); assert(store.schemaVersion==1)
local faucet={fixture=true,key="10:20:0:kitchen",x=10,y=20,z=0}
local attached,result=registry.attachObject(store,faucet)
assert(attached and result.created and result.networkId=="house")
assert(registry.getRuntimeObject(store,result.nodeId)==faucet)
local report=assert(registry.inspect(store)); assert(report.nodeCount==1 and report.attachedCount==1)
assert(registry.detachObject(store,faucet))
assert(registry.getRuntimeObject(store,result.nodeId)==nil,"unload must clear only runtime attachment")
assert(store.nodeIndex[result.nodeId]~=nil,"unload must preserve persistent node")
local reloaded={fixture=true,key="10:20:0:kitchen",x=10,y=20,z=0}
local ok,reloadResult=registry.attachObject(store,reloaded)
assert(ok and not reloadResult.created and registry.getRuntimeObject(store,result.nodeId)==reloaded)
local conflicting={fixture=true,key="10:20:0:kitchen",system="other",x=10,y=20,z=0}
assert(registry.attachObject(store,conflicting)==false,"stable identity conflict must fail")
assert(registry.validate(store))
assert(registry.decommissionNode(store,result.nodeId))
assert(registry.inspect(store).nodeCount==0 and registry.inspect(store).networkCount==0)
isClient=function() return true end
assert(registry.attachObject(store,{fixture=true,key="client"})==false)
isClient=function() return false end
assert(registry.attachStore({schemaVersion=99})==false)
print("B47ANCEDWaterworks persistent registry and runtime attachment checks passed")
next=nil -- Build 42 Kahlua release compatibility.
