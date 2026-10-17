isClient=function() return false end
local network=dofile(arg[1])
local state=network.newState({maxDegree=2})
assert(network.addNode(state,{id="a",kind="source",x=1,y=2,z=0}))
assert(network.addNode(state,{id="b"}))
assert(network.addNode(state,{id="c"}))
assert(network.addNode(state,{id="d"}))
assert(not network.addNode(state,{id="a"}))
assert(not network.addNode(state,{id="bad\nnode"}))
assert(network.connect(state,"a","b"))
assert(network.connect(state,"b","c"))
assert(not network.connect(state,"b","d"),"degree bound must be enforced")
assert(not network.connect(state,"a","a"))
local same,reason=network.areConnected(state,"a","c")
assert(same==nil and reason=="topology pending")
local steps=0
repeat
    local report=assert(network.stepTopology(state,1))
    assert(report.work<=1,"rebuild exceeded explicit work budget")
    steps=steps+1
until report.complete
assert(steps>1 and network.areConnected(state,"a","c")==true)
assert(network.areConnected(state,"a","d")==false)
assert(network.disconnect(state,"b","c"))
while not network.stepTopology(state,2).complete do end
assert(network.areConnected(state,"a","c")==false)
assert(network.connect(state,"c","d"))
assert(network.stepTopology(state,1).complete==false)
assert(network.disconnect(state,"c","d"),"mutation during rebuild must be accepted")
while not network.stepTopology(state,1).complete do end
assert(network.areConnected(state,"c","d")==false,"stale rebuild must never publish")
local neighbors=assert(network.getNeighbors(state,"a")); assert(#neighbors==1 and neighbors[1]=="b")
local inspection=assert(network.inspect(state)); assert(inspection.nodeCount==4 and inspection.edgeCount==1)
assert(network.validate(state))

local channels=network.newState()
assert(network.addNode(channels,{id="water",channel="WATER"}))
assert(network.addNode(channels,{id="fuel",channel="FUEL"}))
assert(not network.connect(channels,"water","fuel"),"cross-fluid edges must fail")
isClient=function() return true end
assert(network.addNode(channels,{id="client"})==false,"client mutation must fail")
isClient=function() return false end
local malformed=network.newState(); malformed.adjacency.ghost={}
assert(network.validate(malformed)==false)
assert(network.stepTopology({schemaVersion=99},1)==nil)
print("B47ANCEDWaterworks bounded network topology checks passed")
next=nil -- Build 42 Kahlua release compatibility.
