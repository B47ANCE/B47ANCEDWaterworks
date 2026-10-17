isClient=function()return false end
local sent={};sendServerCommand=function(...)sent[#sent+1]={...}end
Events={OnClientCommand={Add=function()end},OnTick={Add=function()end}}
local api=dofile(arg[1]);local network=dofile(arg[2]);local registry=dofile(arg[3]);dofile(arg[4]);local vanilla=dofile(arg[5]);local commands=dofile(arg[6])
local fluid={getAmount=function()return 4 end,getCapacity=function()return 10 end,isWaterSource=function()return true end,getRainCatcher=function()return 0 end}
local object={md={}};function object:getFluidContainer()return fluid end;function object:getModData()return self.md end
function object:getX()return 2 end;function object:getY()return 1 end;function object:getZ()return 0 end
function object:getObjectIndex()return 3 end;function object:getSpriteName()return "fixtures_sinks_01_0"end
function object:transmitModData()self.transmitted=true end
local objects={object};function objects:size()return #self end;function objects:get(i)return self[i+1]end
local square={getObjects=function()return objects end};local cell={getGridSquare=function(_,x,y,z)if x==2 and y==1 and z==0 then return square end end};getCell=function()return cell end
local store=registry.newStore();assert(registry.attachStore(store));local server=dofile(arg[7])
local player={getX=function()return 1 end,getY=function()return 1 end,getZ=function()return 0 end}
local ok,result=server.handle(commands.MODULE,commands.CLAIM_FIXTURE,player,{requestId="f1",x=2,y=1,z=0,objectIndex=3,spriteName="fixtures_sinks_01_0"})
assert(ok and result.ok and result.proposal.created and object.transmitted)
local state=assert(waterWorks.inspectInfrastructureNode(store,result.proposal.nodeId))
assert(state.kind=="source"and state.amount==4 and state.capacity==10)
local spoof=server.handle(commands.MODULE,commands.CLAIM_FIXTURE,player,{requestId="f2",x=2,y=1,z=0,objectIndex=3,spriteName="wrong"})
assert(spoof==false,"fixture identity must be reconstructed exactly")
print("B47ANCEDWaterworks exact vanilla fixture claim checks passed")
