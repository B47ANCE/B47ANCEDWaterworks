isClient=function() return false end
local sent={}; sendServerCommand=function(...) sent[#sent+1]={...} end
Events={OnClientCommand={Add=function()end},OnTick={Add=function()end}}
local power=dofile(arg[1]); power.registerBattery({item="B47ANCEDPower.BatteryLithiumPack",size="PACK",capacity=15})
dofile(arg[2]); local registry=dofile(arg[3]); dofile(arg[4]); dofile(arg[5]); dofile(arg[6]); local commands=dofile(arg[7])
local item={id=77,md={}}
function item:getID()return self.id end; function item:getFullType()return "waterWorks.PortableTransferPump" end
function item:getModData()return self.md end; function item:getUseDelta()return 0 end; function item:setUseDelta()end
local object={item=item,md={}}
function object:getItem()return self.item end; function object:getModData()return self.md end
function object:getX()return 2 end; function object:getY()return 1 end; function object:getZ()return 0 end
function object:getObjectIndex()return 4 end
local objects={object}; function objects:size()return #self end; function objects:get(i)return self[i+1] end
local square={getWorldObjects=function()return objects end}; local cell={getGridSquare=function(_,x,y,z)if x==2 and y==1 and z==0 then return square end end}; getCell=function()return cell end
local store=registry.newStore(); assert(registry.attachStore(store)); local server=dofile(arg[8])
local player={getX=function()return 1 end,getY=function()return 1 end,getZ=function()return 0 end}
local ok,result=server.handle(commands.MODULE,commands.CLAIM_PUMP,player,{requestId="claim-1",itemId="77",x=2,y=1,z=0})
assert(ok and result.ok and result.proposal.nodeId=="waterWorks.portablePump:2:1:0:4")
local revision=store.revision; local replay=server.handle(commands.MODULE,commands.CLAIM_PUMP,player,{requestId="claim-1",itemId="77",x=2,y=1,z=0})
assert(replay==true and store.revision==revision,"replayed placement must not attach twice")
local missing=server.handle(commands.MODULE,commands.CLAIM_PUMP,player,{requestId="claim-2",itemId="999",x=2,y=1,z=0}); assert(missing==false)
local far=server.handle(commands.MODULE,commands.CLAIM_PUMP,{getX=function()return 99 end,getY=function()return 99 end,getZ=function()return 0 end},{requestId="claim-3",itemId="77",x=2,y=1,z=0}); assert(far==false)
print("B47ANCEDWaterworks server-authoritative placed-pump claim checks passed")
