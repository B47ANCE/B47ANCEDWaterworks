local waterWorks=rawget(_G,"waterWorks")or require "waterWorks/API"
local Sampling=waterWorks.Sampling or require "waterWorks/Sampling"
local Distribution={}
local function roll(chance)
    if type(ZombRand)=="function"then return ZombRand(100000)<math.floor(chance*100000)end
    return math.random()<chance
end
function Distribution.onFill(roomType,containerType,container)
    if not Sampling.isEnabled()or not container or tostring(container):find("ItemPickerContainer",1,true)then return false end
    local context=string.lower(tostring(roomType or"").." "..tostring(containerType or""))
    local eligible=context:find("laborator",1,true)or context:find("medical",1,true)
        or context:find("pharmacy",1,true)or context:find("hospital",1,true)or context:find("camping",1,true)
    if not eligible or not roll(Sampling.getLootChance())then return false end
    local ok,item=pcall(function()return container:AddItem(Sampling.KIT_TYPE)end)
    return ok and item~=nil
end
if Events and Events.OnFillContainer then Events.OnFillContainer.Add(Distribution.onFill)end
waterWorks.SamplingDistribution=Distribution
return Distribution
