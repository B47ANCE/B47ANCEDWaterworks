local f=dofile("tests/helpers/sediment_fixture.lua")
local C=require "waterWorks/Commands"
Events={OnClientCommand={Add=function()end},OnTick={Add=function()end}}
local replies={};sendServerCommand=function(...)replies[#replies+1]={...}end
local list={f.world};function list:size()return #self end;function list:get(i)return self[i+1]end
getCell=function()return{getGridSquare=function(_,x,y,z)if x==0 and y==0 and z==0 then return{getWorldObjects=function()return list end}end end}end
local server=require "waterWorks/CommandServer"
local function command(args)server.refill();return server.handle(C.MODULE,C.SEDIMENT,f.actor,args)end
local ok,result=command{requestId="claim:1",operation="claim",x=0,y=0,z=0,itemId="7"}
assert(ok and result.ok,result.reason)
local node=result.proposal.nodeId
assert(not command{requestId="forged:capacity",operation="replace",nodeId=node,mediaId=tostring(f.cartridge.id),expectedGeneration=0,capacity=9999})
assert(f.removed()==0)
assert(not command{requestId="wrong:media",operation="replace",nodeId=node,mediaId="foreign",expectedGeneration=0})
local args={requestId="replace:1",operation="replace",nodeId=node,mediaId=tostring(f.cartridge.id),expectedGeneration=0}
assert(command(args)and f.removed()==1);assert(command(args)and f.removed()==1)
assert(not command{requestId="stale:gen",operation="replace",nodeId=node,mediaId="21",expectedGeneration=0})
assert(f.Network.connect(f.store.networks.WATER,node,f.targetId))
while not f.Network.stepTopology(f.store.networks.WATER,8).complete do end
f.actor.x=20
assert(not command{requestId="far:filter",operation="filter",nodeId=node,targetId=f.targetId,expectedGeneration=1})
f.actor.x=0;f.actor.z=1
assert(not command{requestId="floor:filter",operation="filter",nodeId=node,targetId=f.targetId,expectedGeneration=1})
f.actor.z=0;f.actor.dead=true
assert(not command{requestId="dead:filter",operation="filter",nodeId=node,targetId=f.targetId,expectedGeneration=1})
f.actor.dead=false
assert(not command{requestId="forged:quality",operation="filter",nodeId=node,targetId=f.targetId,expectedGeneration=1,quality={particulate=0}})
args={requestId="filter:1",operation="filter",nodeId=node,targetId=f.targetId,expectedGeneration=1}
assert(command(args));local remaining=f.H.recordFor(f.store,f.world).remaining
assert(command(args)and f.H.recordFor(f.store,f.world).remaining==remaining)
assert(f.api.getQuality(f.target).chemical==.4 and f.fluid.amount==5)
local nan=0/0
assert(not command{requestId="nan:claim",operation="claim",x=nan,y=0,z=0,itemId="7"})
isClient=function()return true end
assert(not command{requestId="client:filter",operation="filter",nodeId=node,targetId=f.targetId,expectedGeneration=1})
assert(f.H.recordFor(f.store,f.world).remaining==remaining)
print("sediment server: exact world/item identity, payload, reach/floor/life, replay and client denial PASS")
