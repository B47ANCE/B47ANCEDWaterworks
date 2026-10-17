local sent={};sendClientCommand=function(...)sent[#sent+1]={...}end
Events={OnServerCommand={Add=function()end}};waterWorks={}
local commands=dofile(arg[1]);local client=dofile(arg[2])
local item={getID=function()return 12 end,getFullType=function()return"Base.WaterBottle"end}
local world={getX=function()return 1 end,getY=function()return 2 end,getZ=function()return 0 end,getItem=function()return item end}
local player={};local ok,id=client.request(player,world,"inspect")
assert(ok and type(id)=="string"and sent[1][3]==commands.SAMPLE and sent[1][4].targetKind=="worldItem")
local kit={getID=function()return 99 end};assert(client.request(player,world,"kit",kit))
assert(sent[2][4].kitId=="99")
local fixture={getX=function()return 3 end,getY=function()return 4 end,getZ=function()return 0 end,
    getObjectIndex=function()return 7 end,getSpriteName=function()return"fixtures_sinks_01_0"end}
local identity=assert(client.identity(fixture));assert(identity.targetKind=="object"and identity.objectIndex==7)
local visual=assert(client.format{mode="inspect",amount=2,capacity=5,appearance="CLEAR",odor="NO_OBVIOUS_ODOR",vanillaTainted=false})
assert(visual:find("cannot rule out invisible contamination",1,true))
local tested=assert(client.format{mode="kit",amount=2,capacity=5,appearance="CLOUDY",odor="UNUSUAL_ODOR",
    vanillaTainted=true,qualityState="UNSAFE",treatment="untreated",axes={biological="HIGH",particulate="LOW",
        chemical="NONE",salinity="NONE",turbidity="MODERATE"}})
assert(tested:find("Biological: High",1,true)and tested:find("Overall: Unsafe",1,true))
assert(client.receive(commands.MODULE,commands.SAMPLE_RESULT,{ok=true,requestId=id,report={mode="inspect",amount=1,capacity=2,
    appearance="CLEAR",odor="NO_OBVIOUS_ODOR",vanillaTainted=false}})and#client.Results==1)
assert(client.receive("other",commands.SAMPLE_RESULT,{})==false)
print("B47ANCEDWaterworks sampling client identity and presentation checks passed")
