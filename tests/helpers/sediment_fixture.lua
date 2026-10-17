isClient=function()return false end
local api=require "waterWorks/API"
local Registry=require "waterWorks/Registry"
local Network=require "waterWorks/Network"
local Infrastructure=require "waterWorks/Infrastructure"
local H=require "waterWorks/FirstPartySediment"
local removed=0
sendRemoveItemFromContainer=function()removed=removed+1 end
local function container()
    local c={items={}}
    function c:getItems()return self.items end
    function c:contains(item)for _,v in ipairs(self.items)do if v==item then return true end end;return false end
    function c:Remove(item)
        if self.reject then return end
        for i,v in ipairs(self.items)do if v==item then table.remove(self.items,i);item.container=nil;return end end
    end
    return c
end
local root,nested=container(),container()
root.items[1]={getInventory=function()return nested end,getContainer=function()return root end}
local nextId=20
local function media()
    nextId=nextId+1
    local m={id=nextId,container=nested,getFullType=function()return H.MEDIA_TYPE end}
    function m:getID()return self.id end;function m:getContainer()return self.container end
    nested.items[#nested.items+1]=m;return m
end
local cartridge=media()
local actor={x=0,y=0,z=0,dead=false}
function actor:getX()return self.x end;function actor:getY()return self.y end;function actor:getZ()return self.z end
function actor:isDead()return self.dead end;function actor:getOnlineID()return 42 end
function actor:getInventory()return root end;function actor:removeFromHands()end
local owned={md={},getID=function()return 7 end,getFullType=function()return H.HOUSING_TYPE end}
function owned:getModData()return self.md end
local world={md={},x=0,y=0,z=0}
function world:getItem()return owned end;function world:getModData()return self.md end
function world:getX()return self.x end;function world:getY()return self.y end;function world:getZ()return self.z end
function world:transmitModData()self.sent=(self.sent or 0)+1 end
local fluid={amount=5,capacity=10,isTaintedWater=function()return true end,isWaterOnlySource=function()return true end}
function fluid:getAmount()return self.amount end;function fluid:getCapacity()return self.capacity end
local target={water=true,key="tank",x=1,md={waterWorksQuality={biological=.8,particulate=1,chemical=.4,salinity=.2,turbidity=.8,treatment="untreated"}}}
function target:getFluidContainer()return fluid end;function target:getModData()return self.md end
function target:sync()end;function target:setTaintedWater(value)self.tainted=value end
function target:getX()return self.x end;function target:getY()return 0 end;function target:getZ()return 0 end
Infrastructure.registerProvider{id="test.sedimentWater",kind="storage",matches=function(o)return o.water end,
    describe=function(o)return{networkId="WATER",stableKey=o.key,x=o.x,y=0,z=0}end,
    getState=function()return{amount=fluid.amount,capacity=fluid.capacity}end}
local store=Registry.newStore();assert(Registry.attachStore(store))
local ok,attached=Registry.attachObject(store,target);assert(ok)
return{api=api,Registry=Registry,Network=Network,H=H,Infrastructure=Infrastructure,actor=actor,world=world,
    owned=owned,cartridge=cartridge,media=media,root=root,nested=nested,target=target,targetId=attached.nodeId,
    fluid=fluid,store=store,removed=function()return removed end}
