isClient=function() return false end
FluidContainer={CanTransfer=function()return true end,Transfer=function(a,b,n)a.amount=a.amount-n;b.amount=b.amount+n end}
local sent={}; sendServerCommand=function(...)sent[#sent+1]={...}end
Events={OnClientCommand={Add=function()end},OnTick={Add=function()end}}
dofile(arg[1]); local network=dofile(arg[2]); local registry=dofile(arg[3]); local infrastructure=dofile(arg[4])
dofile(arg[5]); local flow=dofile(arg[6]); dofile(arg[7]); local commands=dofile(arg[8])
for _,kind in ipairs({"source","storage"}) do local role=kind; infrastructure.registerProvider({id="command.flow."..role,kind=role,
    matches=function(o)return o.kind==role end,describe=function(o)return {networkId="local",stableKey=o.kind,channel="WATER",x=o.x,y=0,z=0} end,
    getState=function(o)return {amount=o.fluid.amount,capacity=o.fluid.capacity,supply=role=="source" and 10 or 0} end}) end
local function object(kind,x,amount)local fluid={amount=amount,capacity=10,isTaintedWater=function()return false end}; function fluid:getAmount()return self.amount end; function fluid:getCapacity()return self.capacity end
    local o={kind=kind,x=x,fluid=fluid,md={}}; function o:getFluidContainer()return self.fluid end; function o:getModData()return self.md end; function o:sync()end; return o end
local source,target=object("source",0,6),object("storage",1,0); local store=registry.newStore(); assert(registry.attachStore(store))
local _,a=registry.attachObject(store,source); local _,b=registry.attachObject(store,target); assert(network.connect(store.networks["local"],a.nodeId,b.nodeId))
while not network.stepTopology(store.networks["local"],4).complete do end
local server=dofile(arg[9]); local player={getX=function()return 0 end,getY=function()return 0 end,getZ=function()return 0 end}
local ok,result=server.handle(commands.MODULE,commands.FLOW,player,{requestId="flow-command-1",sourceId=a.nodeId,targetId=b.nodeId,amount=2})
assert(ok and result.ok and result.proposal.amount==2 and source.fluid.amount==4 and target.fluid.amount==2)
local replay=server.handle(commands.MODULE,commands.FLOW,player,{requestId="flow-command-1",sourceId=a.nodeId,targetId=b.nodeId,amount=2})
assert(replay==true and source.fluid.amount==4,"replay must not move fluid twice")
local tooMuch=server.handle(commands.MODULE,commands.FLOW,player,{requestId="flow-command-2",sourceId=a.nodeId,targetId=b.nodeId,amount=101}); assert(tooMuch==false)
local far={getX=function()return 99 end,getY=function()return 0 end,getZ=function()return 0 end}
assert(server.handle(commands.MODULE,commands.FLOW,far,{requestId="flow-command-3",sourceId=a.nodeId,targetId=b.nodeId,amount=1})==false)
print("B47ANCEDWaterworks authoritative routed-flow command checks passed")
