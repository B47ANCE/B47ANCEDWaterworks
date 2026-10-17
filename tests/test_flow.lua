isClient=function() return false end
FluidContainer={CanTransfer=function()return true end,Transfer=function(a,b,n)a.amount=a.amount-n;b.amount=b.amount+n end}
local api=dofile(arg[1]); local network=dofile(arg[2]); local registry=dofile(arg[3]); local infrastructure=dofile(arg[4])
local hydraulics=dofile(arg[5]); local flow=dofile(arg[6])
local function provider(kind)
    local role=kind
    infrastructure.registerProvider({id="flow."..role,kind=role,priority=10,
        matches=function(o)return o.kind==role end,
        describe=function(o)return {networkId="system",stableKey=o.key,channel="WATER",x=o.x,y=0,z=0} end,
        getState=function(o)return o.state end})
end
for _,kind in ipairs({"source","junction","valve","storage"}) do provider(kind) end
local store=registry.newStore(); assert(registry.attachStore(store)); local loaded={}; local ids={}
local function add(key,kind,x,state,amount,capacity)
    local fluid={amount=amount or 0,capacity=capacity or 10,isTaintedWater=function()return false end}
    function fluid:getAmount()return self.amount end; function fluid:getCapacity()return self.capacity end
    local object={key=key,kind=kind,x=x,state=state or {},data={}}
    function object:getFluidContainer()return fluid end; function object:getModData()return self.data end; function object:sync()end
    loaded[#loaded+1]=object; local ok,result=registry.attachObject(store,object); assert(ok); ids[#ids+1]=result.nodeId; return object
end
local source=add("source","source",0,{supply=10,pressure=20},8,10)
add("pipe","junction",1,{}); local valve=add("valve","valve",2,{open=true}); local target=add("tank","storage",3,{amount=0,capacity=10},0,10)
local graph=store.networks.system; for i=1,#ids-1 do assert(network.connect(graph,ids[i],ids[i+1])) end
while not network.stepTopology(graph,8).complete do end
while not hydraulics.step(store,"system",8).complete do end
local ok,result=flow.transfer(store,ids[1],ids[4],3,{minimumPressure=5,operationId="flow-1"})
assert(ok and result.amount==3 and result.pathLength==4 and source:getFluidContainer().amount==5 and target:getFluidContainer().amount==3)
assert(hydraulics.getReport(store,"system")==nil,"successful transfer must invalidate hydraulic report")
valve.state.open=false
assert(flow.transfer(store,ids[1],ids[4],1)==false,"closed valve must block route")
isClient=function() return true end; assert(flow.transfer(store,ids[1],ids[4],1)==false)
print("B47ANCEDWaterworks bounded routed fluid transaction checks passed")
