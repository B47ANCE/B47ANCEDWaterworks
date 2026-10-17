next=nil -- Build 42 Kahlua release compatibility.
local requested
package.loaded["waterWorks/CommandClient"]={requestSnapshot=function(...)requested={...};return true end}
local Inspector=dofile(arg[1])
local text=assert(Inspector.format({networkId="house<unsafe>",revision=7,componentCount=2,complete=true,
    nodes={b={id="b",kind="pump",enabled=false,x=2,y=3,z=0,componentId=2},
        a={id="a",kind="storage",enabled=true,x=1,y=3,z=0,componentId=1}},
    edges={["a\0b"]={a="a",b="b"}}}))
assert(text:find("house&lt;unsafe&gt;",1,true)and text:find("Nodes: 2",1,true)and text:find("Connections: 1",1,true))
assert(text:find("pump: 1",1,true)and text:find("storage: 1",1,true),"inspector must summarize node roles")
local player={};assert(Inspector.open(player,{networkId="house",node={id="anchor"}},0))
assert(requested and requested[1]==player and requested[2]=="house"and requested[3]=="anchor")
assert(not Inspector.open(nil,{},0),"missing endpoints must fail closed")
print("B47ANCEDWaterworks bounded player-facing network inspector checks passed")
