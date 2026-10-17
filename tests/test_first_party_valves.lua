isClient=function()return false end
local network=dofile(arg[1]);local registry=dofile(arg[2]);dofile(arg[3]);local valves=dofile(arg[4])
local item={condition=50}
function item:getFullType()return valves.INLINE_TYPE end
function item:getCondition()return self.condition end
function item:getConditionMax()return 100 end
local world={item=item,md={}}
function world:getItem()return self.item end;function world:getModData()return self.md end
function world:getX()return 4 end;function world:getY()return 5 end;function world:getZ()return 0 end
function world:getObjectIndex()return 2 end;function world:transmitModData()self.transmitted=true end
local store=registry.newStore();assert(registry.attachStore(store))
local ok,result=valves.claim(store,world,"house");assert(ok and result.nodeId=="waterWorks.inlineValve:4:5:0:2")
local state=assert(waterWorks.inspectInfrastructureNode(store,result.nodeId))
assert(state.kind=="valve"and state.open==true and state.condition==50 and state.flowLimit==5)
local changed,closed=waterWorks.requestInfrastructureAction(store,result.nodeId,"set-open",{open=false})
assert(changed and closed.open==false and world.md[valves.MARKER_KEY].open==false and world.transmitted)
assert(valves.claim(store,world,"house")==false,"duplicate valve claims must be rejected")
print("B47ANCEDWaterworks first-party inline valve checks passed")
