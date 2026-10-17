isClient=function()return false end
local sent={};sendServerCommand=function(...)sent[#sent+1]={...}end
Events={OnClientCommand={Add=function()end},OnTick={Add=function()end}}
dofile(arg[1]);local network=dofile(arg[2]);local registry=dofile(arg[3]);dofile(arg[4]);local condition=dofile(arg[5]);local maintenance=dofile(arg[6]);local commands=dofile(arg[7])
registry.registerProvider({id="test.pipe",matches=function(o)return o.pipe end,
    describe=function(o)return{networkId="repair",stableKey=o.key,kind="junction",channel="WATER",x=o.x,y=0,z=0}end})
local pipe={pipe=true,key="pipe",x=1,getX=function(s)return s.x end,getY=function()return 0 end,getZ=function()return 0 end}
local store=registry.newStore();assert(registry.attachStore(store));local _,attached=registry.attachObject(store,pipe)
assert(condition.set(store,attached.nodeId,{condition=.5,leakRatePerHour=8}))
local function kit(id,removeWorks)
    local item={id=id,md={}};local container={items={}}
    function item:getID()return self.id end;function item:getFullType()return maintenance.PATCH_TYPE end
    function item:getContainer()return container end;function item:getModData()return self.md end;function item:transmitModData()end
    container.items[1]=item;function container:getItems()return self.items end
    function container:contains(value)for _,v in ipairs(self.items)do if v==value then return true end end;return false end
    function container:Remove(value)if removeWorks then for i,v in ipairs(self.items)do if v==value then table.remove(self.items,i);return end end end end
    return item,container
end
local item,inventory=kit(11,true)
local player={getInventory=function()return inventory end,removeFromHands=function()end,
    getX=function()return 0 end,getY=function()return 0 end,getZ=function()return 0 end}
local server=dofile(arg[8])
local ok,result=server.handle(commands.MODULE,commands.REPAIR,player,
    {requestId="repair-1",nodeId=attached.nodeId,kitId="11"})
assert(ok and result.ok and result.proposal.conditionAfter==.75 and result.proposal.leakAfter==3,
    string.format("repair mismatch ok=%s wire=%s reason=%s",tostring(ok),tostring(type(result)=="table"and result.ok),
        tostring(type(result)=="table"and result.reason or result)))
local replay=server.handle(commands.MODULE,commands.REPAIR,player,
    {requestId="repair-1",nodeId=attached.nodeId,kitId="11"})
assert(replay==true and condition.inspect(store,attached.nodeId).condition==.75,"command replay must not repair twice")

local bad,badInventory=kit(12,false);player.getInventory=function()return badInventory end
local before=condition.inspect(store,attached.nodeId)
local failed,reason,details=maintenance.repair(store,attached.nodeId,player,"12","repair-rollback")
local after=condition.inspect(store,attached.nodeId)
assert(not failed and details.rolledBack and reason:find("removal rejected",1,true))
assert(after.condition==before.condition and after.leakRatePerHour==before.leakRatePerHour
    and bad.md.waterWorksMaintenanceRecovery==nil,"confirmed resource failure must restore exact condition state")

local function uncertainKit(id)
    local item={id=id,md={}};local container={items={}}
    function item:getID()return self.id end;function item:getFullType()return maintenance.PATCH_TYPE end
    function item:getContainer()return container end;function item:getModData()return self.md end;function item:transmitModData()end
    container.items[1]=item;function container:getItems()return self.items end
    function container:contains(value)self.checks=(self.checks or 0)+1;if self.checks==1 then return value==item end;return nil end
    function container:Remove()end
    return item,container
end
local uncertain,uncertainInventory=uncertainKit(13);player.getInventory=function()return uncertainInventory end
local uncertainOk,uncertainReason,uncertainDetails=maintenance.repair(store,attached.nodeId,player,"13","repair-uncertain-1")
assert(not uncertainOk and uncertainDetails.uncertain and uncertainReason:find("uncertain",1,true))
local page=assert(maintenance.listRecoveries(store,nil,1));assert(#page.entries==1 and page.entries[1].nodeId==attached.nodeId)
assert(not maintenance.listRecoveries(store,"missing",1))
local accepted,acceptReceipt=maintenance.resolveRecovery(store,attached.nodeId,"acceptCommitted")
assert(accepted and acceptReceipt.resolution=="acceptCommitted"and maintenance.inspectRecovery(store,attached.nodeId)==nil)

assert(condition.damage(store,attached.nodeId,.2,2,"test"));local damaged=condition.inspect(store,attached.nodeId)
local uncertain2,uncertainInventory2=uncertainKit(14);player.getInventory=function()return uncertainInventory2 end
local secondOk,_,secondDetails=maintenance.repair(store,attached.nodeId,player,"14","repair-uncertain-2")
assert(not secondOk and secondDetails.uncertain)
local restored,restoreReceipt=maintenance.resolveRecovery(store,attached.nodeId,"restoreCondition")
local restoredState=condition.inspect(store,attached.nodeId)
assert(restored and restoreReceipt.resolution=="restoreCondition"and restoredState.condition==damaged.condition
    and restoredState.leakRatePerHour==damaged.leakRatePerHour)
print("B47ANCEDWaterworks atomic patch-kit maintenance checks passed")
