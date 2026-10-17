local added={};local container={AddItem=function(_,kind)added[#added+1]=kind;return{kind=kind}end}
Events={OnFillContainer={Add=function()end}};ZombRand=function()return 0 end
SandboxVars={waterWorks={EnableWaterSampling=true,WaterTestKitLootChance=1}}
waterWorks={Sampling={KIT_TYPE="waterWorks.WaterTestKit",isEnabled=function()
    return SandboxVars.waterWorks.EnableWaterSampling~=false end,getLootChance=function()return SandboxVars.waterWorks.WaterTestKitLootChance end}}
local distribution=dofile(arg[1])
assert(distribution.onFill("laboratory","counter",container)and added[1]=="waterWorks.WaterTestKit")
assert(not distribution.onFill("bedroom","wardrobe",container)and#added==1)
SandboxVars.waterWorks.EnableWaterSampling=false
assert(not distribution.onFill("medical","tools",container)and#added==1)
print("B47ANCEDWaterworks bounded configurable test-kit distribution checks passed")
