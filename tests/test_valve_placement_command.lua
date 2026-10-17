isClient=function()return false end
local sent={};sendServerCommand=function(...)sent[#sent+1]={...}end
Events={OnClientCommand={Add=function()end},OnTick={Add=function()end}}
local network=dofile(arg[1]);local registry=dofile(arg[2]);dofile(arg[3]);local valves=dofile(arg[4]);local commands=dofile(arg[5])
local item={id=88,condition=100};function item:getID()return self.id end
function item:getFullType()return valves.INLINE_TYPE end;function item:getCondition()return self.condition end
function item:getConditionMax()return 100 end
local object={item=item,md={}};function object:getItem()return self.item end;function object:getModData()return self.md end
function object:getX()return 2 end;function object:getY()return 1 end;function object:getZ()return 0 end
function object:getObjectIndex()return 6 end;function object:transmitModData()end
local objects={object};function objects:size()return #self end;function objects:get(i)return self[i+1]end
local square={getWorldObjects=function()return objects end};local cell={getGridSquare=function(_,x,y,z)if x==2 and y==1 and z==0 then return square end end};getCell=function()return cell end
local store=registry.newStore();assert(registry.attachStore(store));local server=dofile(arg[6])
local player={getX=function()return 1 end,getY=function()return 1 end,getZ=function()return 0 end}
local ok,result=server.handle(commands.MODULE,commands.CLAIM_VALVE,player,{requestId="v1",itemId="88",x=2,y=1,z=0})
assert(ok and result.ok);local nodeId=result.proposal.nodeId
local toggled,toggleResult=server.handle(commands.MODULE,commands.SET_VALVE,player,{requestId="v2",nodeId=nodeId,open=false})
assert(toggled and toggleResult.ok and toggleResult.proposal.open==false)
local replay=server.handle(commands.MODULE,commands.SET_VALVE,player,{requestId="v2",nodeId=nodeId,open=true})
assert(replay==true and waterWorks.inspectInfrastructureNode(store,nodeId).open==false,"replay must not retoggle valve")
local far=server.handle(commands.MODULE,commands.SET_VALVE,{getX=function()return 99 end,getY=function()return 99 end,getZ=function()return 0 end},{requestId="v3",nodeId=nodeId,open=true})
assert(far==false)
print("B47ANCEDWaterworks server-authoritative valve claim/action checks passed")
