local waterWorks=rawget(_G,"waterWorks")or require "waterWorks/API"
local Client=waterWorks.CommandClient or require "waterWorks/CommandClient"
local Vanilla=waterWorks.VanillaProviders or require "waterWorks/VanillaProviders"
local Menu={MAX_OBJECTS=128}

local function call(object,name,...)
    local ok,fn=pcall(function()return object and object[name]end)
    if not ok or type(fn)~="function"then return nil end
    local called,value=pcall(fn,object,...);return called and value or nil
end
local function candidate(object)
    if not object or call(object,"getFluidContainer")==nil or call(object,"getModData")==nil then return false end
    local index,sprite=tonumber(call(object,"getObjectIndex")),call(object,"getSpriteName")
    if not index or index~=math.floor(index)or index<0 or type(sprite)~="string"or sprite==""then return false end
    return Vanilla.inspectClaim(object)==nil
end
local function claim(object,index)
    local actor=type(getSpecificPlayer)=="function"and getSpecificPlayer(index)or nil
    local ok,reason=actor and Client.claimVanillaFixture(actor,object)
    if not ok and print then print("[B47ANCEDWaterworks] Fixture registration failed safely: "..tostring(reason))end
    return ok==true
end

function Menu.fill(index,context,worldObjects,test)
    if not waterWorks.isFeatureEnabled("EnableNetworkContextActions")then return end
    if not context or type(context.addOption)~="function"then return end
    local seen,count={},0
    for _,object in ipairs(type(worldObjects)=="table"and worldObjects or{})do
        count=count+1;if count>Menu.MAX_OBJECTS then break end
        if not seen[object]and candidate(object)then
            seen[object]=true;if test then return true end
            context:addOption("Register Water Infrastructure",object,claim,index)
        end
    end
end

if Events and Events.OnFillWorldObjectContextMenu then Events.OnFillWorldObjectContextMenu.Add(Menu.fill)end
waterWorks.FixtureContextMenu=Menu
return Menu
