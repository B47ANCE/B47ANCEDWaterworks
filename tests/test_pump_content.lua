local handle=assert(io.open(arg[1],"rb"));local text=handle:read("*a");handle:close()
assert(text:find("craftRecipe%s+AssemblePortableTransferPump"),"assembly recipe missing")
for _,input in ipairs({"Base.EngineParts","Base.RubberHose","Base.MetalPipe","Base.SmallSheetMetal",
    "Base.ElectricWire","Base.ElectronicsScrap","Base.DuctTape","Base.PipeWrench"})do
    assert(text:find(input,1,true),"assembly input missing: "..input)
end
assert(text:find("ConditionMax%s*=%s*100"),"pump condition missing")
assert(text:find("base:repairwithtape",1,true)and text:find("base:repairwithglue",1,true),
    "native in-place repair tags missing")
assert(text:find("item 1 waterWorks.PortableTransferPump",1,true),"assembly output missing")
assert(text:find("item%s+ElectricWaterPurifier"),"electric purifier item missing")
assert(text:find("craftRecipe%s+AssembleElectricWaterPurifier"),"purifier recipe missing")
assert(text:find("item 1 waterWorks.ElectricWaterPurifier",1,true),"purifier output missing")
assert(text:find("item%s+InfrastructurePatchKit"),"patch kit item missing")
assert(text:find("craftRecipe%s+AssembleInfrastructurePatchKit"),"patch kit recipe missing")
assert(text:find("item 1 waterWorks.InfrastructurePatchKit",1,true),"patch kit output missing")
assert(text:find("item%s+InlineShutoffValve"),"inline valve item missing")
assert(text:find("craftRecipe%s+AssembleInlineShutoffValve"),"inline valve recipe missing")
assert(text:find("item 1 waterWorks.InlineShutoffValve",1,true),"inline valve output missing")
assert(text:find("item%s+WaterTestKit"),"water test kit item missing")
assert(text:find("ItemType%s*=%s*base:drainable")and text:find("UseDelta%s*=%s*0%.1"),
    "water test kit must expose ten reagent uses")
print("B47ANCEDWaterworks native portable-pump crafting and servicing content checks passed")
