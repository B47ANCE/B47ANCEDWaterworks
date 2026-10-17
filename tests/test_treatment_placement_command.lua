isClient=function()return false end
local sent={};sendServerCommand=function(...)sent[#sent+1]={...}end
Events={OnClientCommand={Add=function()end},OnTick={Add=function()end}}
local power=dofile(arg[1]);power.registerBattery({item="B47ANCEDPower.BatteryLithiumPack",size="PACK",capacity=15})
dofile(arg[2]);dofile(arg[3]);local registry=dofile(arg[4]);dofile(arg[5]);dofile(arg[6]);dofile(arg[7]);local commands=dofile(arg[8])
local item={id=88,md={}}
function item:getID()return self.id end;function item:getFullType()return"waterWorks.ElectricWaterPurifier"end
function item:getModData()return self.md end;function item:getCondition()return 100 end;function item:getConditionMax()return 100 end
local object={item=item,md={}}
function object:getItem()return self.item end;function object:getModData()return self.md end
function object:getX()return 3 end;function object:getY()return 1 end;function object:getZ()return 0 end
function object:getObjectIndex()return 5 end
local objects={object};function objects:size()return #self end;function objects:get(i)return self[i+1]end
local square={getWorldObjects=function()return objects end};local cell={getGridSquare=function(_,x,y,z)if x==3 and y==1 and z==0 then return square end end};getCell=function()return cell end
local store=registry.newStore();assert(registry.attachStore(store));local server=dofile(arg[9])
local player={getX=function()return 2 end,getY=function()return 1 end,getZ=function()return 0 end}
local ok,result=server.handle(commands.MODULE,commands.CLAIM_TREATMENT,player,
    {requestId="purifier-claim-1",itemId="88",x=3,y=1,z=0})
assert(ok and result.ok and result.proposal.nodeId=="waterWorks.electricPurifier:3:1:0:5")
local revision=store.revision
local replay=server.handle(commands.MODULE,commands.CLAIM_TREATMENT,player,
    {requestId="purifier-claim-1",itemId="88",x=3,y=1,z=0})
assert(replay==true and store.revision==revision)
print("B47ANCEDWaterworks server-authoritative placed-treatment claim checks passed")
