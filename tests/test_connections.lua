isClient=function() return false end
local network=dofile(arg[1])
local registry=dofile(arg[2])
local connections=dofile(arg[3])
registry.registerProvider({id="test.pipe",matches=function(o)return o.pipe end,
    describe=function(o)return {networkId=o.network,stableKey=o.key,kind="junction",channel="WATER",x=o.x,y=o.y,z=o.z} end})
local store=registry.newStore(); assert(registry.attachStore(store))
local function attach(key,x,y,z,networkId)
    local object={pipe=true,key=key,x=x,y=y,z=z,network=networkId or "house"}
    local ok,result=registry.attachObject(store,object); assert(ok); return object,result.nodeId
end
local a,aId=attach("a",0,0,0); local b,bId=attach("b",1,0,0); local far,farId=attach("far",4,0,0)
local actor={x=0,y=0,z=0}
connections.registerValidator({id="test.permission",validate=function(proposal,context)
    return context.allowed==true,"permission denied"
end})
assert(connections.request(store,"connect",aId,bId,{actor=actor})==false)
local ok,result=connections.request(store,"connect",aId,bId,{actor=actor,allowed=true})
assert(ok and result.operation=="connect")
assert(connections.inspectEdge(store,aId,bId).connected)
assert(connections.request(store,"connect",aId,bId,{actor=actor,allowed=true})==false)
assert(connections.request(store,"connect",bId,farId,{actor=actor,allowed=true})==false,"distance must be server checked")
assert(connections.request(store,"disconnect",aId,bId,{actor={x=50,y=50,z=0},allowed=true})==false)
assert(connections.request(store,"disconnect",aId,bId,{actor=actor,allowed=true}))
assert(not connections.inspectEdge(store,aId,bId).connected)
local other,otherId=attach("other",0,1,0,"other")
assert(connections.request(store,"connect",aId,otherId,{actor=actor,allowed=true})==false)
registry.detachObject(store,b)
assert(connections.request(store,"connect",aId,bId,{actor=actor,allowed=true})==false,"unloaded endpoint must fail")
isClient=function() return true end
assert(connections.request(store,"connect",aId,farId,{actor=actor,allowed=true})==false)
print("B47ANCEDWaterworks server-validated connection workflow checks passed")
