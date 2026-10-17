isClient=function() return false end
local sent={}; sendServerCommand=function(... ) sent[#sent+1]={...} end
Events={OnClientCommand={Add=function()end},OnTick={Add=function()end}}
local network=dofile(arg[1]); local registry=dofile(arg[2]); local connections=dofile(arg[3]); local commands=dofile(arg[4])
registry.registerProvider({id="test.command",matches=function(o)return o.node end,
    describe=function(o)return {networkId="system",stableKey=o.key,kind="junction",channel="WATER",x=o.x,y=0,z=0} end})
local store=registry.newStore(); assert(registry.attachStore(store))
local loaded={}
local function attach(key,x) local o={node=true,key=key,x=x}; loaded[#loaded+1]=o; local ok,r=registry.attachObject(store,o); assert(ok); return r.nodeId end
local a,b=attach("a",0),attach("b",1)
local server=dofile(arg[5]); local player={getX=function()return 0 end,getY=function()return 0 end,getZ=function()return 0 end}
local ok,result=server.handle(commands.MODULE,commands.CONNECT,player,{requestId="one",nodeA=a,nodeB=b})
assert(ok and result.ok and result.reason==nil and #sent==1,"successful commands must not carry a failure reason")
assert(result.proposal.nodeDefinitionA==nil and result.proposal.objectA==nil,"wire result must not expose runtime/internal tables")
local revision=store.networks.system.revision
while store.networks.system.topologyDirty do assert(server.maintainTopology()) end
local subscribed,page=server.handle(commands.MODULE,commands.SUBSCRIBE,player,{networkId="system",anchorNodeId=a})
assert(subscribed,tostring(page)); assert(page.complete and #page.nodes==2)
local replayOk,replay=server.handle(commands.MODULE,commands.CONNECT,player,{requestId="one",nodeA=a,nodeB=b})
assert(replayOk and replay.ok and store.networks.system.revision==revision,"replay must not mutate twice")
local invalid=server.handle(commands.MODULE,commands.CONNECT,player,{requestId="bad\n",nodeA=a,nodeB=b})
assert(invalid==false)
local unhandled=server.handle("other",commands.CONNECT,player,{}); assert(unhandled==nil)
local disconnected=server.handle(commands.MODULE,commands.DISCONNECT,player,{requestId="two",nodeA=a,nodeB=b})
assert(disconnected and #sent>=4,"subscribed mutation must send result and relevant delta")
print("B47ANCEDWaterworks bounded deduplicated command transport checks passed")
next=nil -- Build 42 Kahlua release compatibility.
