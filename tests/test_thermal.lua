_G.waterWorks=nil;isClient=function()return false end
local api=dofile(arg[1]);local network=dofile(arg[2]);local registry=dofile(arg[3]);dofile(arg[4]);local thermal=dofile(arg[5]);local flow=dofile(arg[6])
api.registerInfrastructureProvider({id="thermal.infrastructure",kind="storage",matches=function(o)return o.tank end,describe=function(o)return{networkId="thermal",stableKey=o.key,channel="WATER",x=o.x,y=0,z=0}end,getState=function()return{available=true}end})
local store=registry.newStore();registry.attachStore(store);local a={tank=true,key="a",kind="storage",x=0};local b={tank=true,key="b",kind="storage",x=1}
local _,aa=registry.attachObject(store,a);local _,bb=registry.attachObject(store,b);assert(network.connect(store.networks.thermal,aa.nodeId,bb.nodeId))
assert(thermal.set(store,aa.nodeId,{temperatureC=4,lastProcessedHour=10,responsePerHour=.5}))
local ok,result=thermal.step(store,11,1,function()return -4 end);assert(ok and result.inspected==1)
local state=thermal.inspect(store,aa.nodeId);assert(state.temperatureC==0 and state.frozen==true and state.lastAmbientC==-4)
local route,err=flow.findOpenPath(store,aa.nodeId,bb.nodeId);assert(route==nil and err=="no open loaded path")
assert(thermal.applyHeat(store,aa.nodeId,2));state=thermal.inspect(store,aa.nodeId);assert(state.temperatureC==2 and state.frozen==false)
route=flow.findOpenPath(store,aa.nodeId,bb.nodeId);assert(route and #route.path==2)
isClient=function()return true end;assert(thermal.applyHeat(store,aa.nodeId,1)==false)
print("B47ANCEDWaterworks bounded thermal/freezing checks passed")
next=nil -- Build 42 Kahlua release compatibility.
