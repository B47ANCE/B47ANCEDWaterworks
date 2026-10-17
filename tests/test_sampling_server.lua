isClient=function()return false end
local sent={};sendServerCommand=function(...)sent[#sent+1]={...}end;sendItemStats=function(item)item.synced=true end
Events={OnClientCommand={Add=function()end},OnTick={Add=function()end}}
local api=dofile(arg[1]);local commands=dofile(arg[2]);local sampling=dofile(arg[3])
local fluid={amount=5,capacity=10};function fluid:getAmount()return self.amount end;function fluid:getCapacity()return self.capacity end
function fluid:isTaintedWater()return false end
local object={md={}};function object:getFluidContainer()return fluid end;function object:getModData()return self.md end
function object:getX()return 1 end;function object:getY()return 1 end;function object:getZ()return 0 end
function object:getObjectIndex()return 4 end;function object:getSpriteName()return"fixtures_sinks_01_0"end
function object:transmitModData()end
assert(api.setQuality(object,{biological=.6,particulate=.1,chemical=.2,salinity=0,turbidity=.3,treatment="untreated"}))
local items={};local container={}
function container:getItems()return items end;function container:contains(item)for _,v in ipairs(items)do if v==item then return true end end;return false end
function container:Remove(item)for i,v in ipairs(items)do if v==item then table.remove(items,i);return end end end
local kit={uses=1,id=77};items[1]=kit
function kit:getID()return self.id end;function kit:getFullType()return sampling.KIT_TYPE end;function kit:getContainer()return container end
function kit:getCurrentUsesFloat()return self.uses end;function kit:getUseDelta()return .1 end
function kit:Use()self.uses=self.uses-.1 end
local player={getInventory=function()return container end,
    getX=function()return 1 end,getY=function()return 1 end,getZ=function()return 0 end}
local objects={object};function objects:size()return#self end;function objects:get(index)return self[index+1]end
local square={getObjects=function()return objects end};local cell={getGridSquare=function(_,x,y,z)if x==1 and y==1 and z==0 then return square end end}
getCell=function()return cell end
local server=dofile(arg[4])
local inspect={requestId="inspect",mode="inspect",targetKind="object",x=1,y=1,z=0,objectIndex=4,spriteName="fixtures_sinks_01_0"}
local ok,result=server.handle(commands.MODULE,commands.SAMPLE,player,inspect)
assert(ok and result.reason==nil and result.report.mode=="inspect"and result.report.axes==nil and kit.uses==1)
local tested={requestId="kit",mode="kit",targetKind="object",x=1,y=1,z=0,objectIndex=4,
    spriteName="fixtures_sinks_01_0",kitId="77"}
local testOk,testResult=server.handle(commands.MODULE,commands.SAMPLE,player,tested)
assert(testOk and testResult.report.axes.biological=="HIGH"and math.abs(kit.uses-.9)<.0001 and kit.synced)
local replayOk=server.handle(commands.MODULE,commands.SAMPLE,player,tested)
assert(replayOk and math.abs(kit.uses-.9)<.0001,"request replay must not consume another reagent")
local spoof={requestId="spoof",mode="kit",targetKind="object",x=1,y=1,z=0,objectIndex=4,
    spriteName="wrong",kitId="77"}
assert(server.handle(commands.MODULE,commands.SAMPLE,player,spoof)==false)
player.getX=function()return 20 end;local far={requestId="far",mode="inspect",targetKind="object",x=1,y=1,z=0,
    objectIndex=4,spriteName="fixtures_sinks_01_0"};assert(server.handle(commands.MODULE,commands.SAMPLE,player,far)==false)
assert(#sent==5,"every handled request and replay must receive one bounded result")
print("B47ANCEDWaterworks authoritative world-sampling command checks passed")
