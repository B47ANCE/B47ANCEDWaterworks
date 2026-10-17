require "waterWorks/API"
require "waterWorks/Filters"
require "waterWorks/FilterTransactions"
require "waterWorks/Network"
local registry=require "waterWorks/Registry"
require "waterWorks/Infrastructure"
require "waterWorks/PlumbingConformance"
require "waterWorks/VanillaProviders"
require "waterWorks/Connections"
require "waterWorks/Hydraulics"
require "waterWorks/Flow"
require "waterWorks/PumpPower"
require "waterWorks/FirstPartyPumps"
require "waterWorks/TreatmentDevices"
require "waterWorks/FirstPartyTreatment"
require "waterWorks/FirstPartyValves"
local demandScheduler=require "waterWorks/DemandScheduler"
local condition=require "waterWorks/Condition"
require "waterWorks/Maintenance"
local thermal=require "waterWorks/Thermal"
require "waterWorks/Commands"
require "waterWorks/Diagnostics"
require "waterWorks/Sampling"
require "waterWorks/SamplingDistribution"
local lifecycle=require "waterWorks/Lifecycle"
local function initializeRegistry()
    if ModData and ModData.getOrCreate then
        local ok,err=registry.attachStore(ModData.getOrCreate(registry.STORE_KEY))
        if not ok and print then print("[B47ANCEDWaterworks] Network registry unavailable: "..tostring(err)) end
    end
end
if Events and Events.OnInitGlobalModData then Events.OnInitGlobalModData.Add(initializeRegistry) end
local lifecycleInstalled,lifecycleError=lifecycle.install(Events)
if not lifecycleInstalled and print then print("[B47ANCEDWaterworks] Lifecycle events unavailable: "..tostring(lifecycleError))end
local function processDemands()
    local store=registry.getStore(); local gameTime=type(getGameTime)=="function" and getGameTime() or nil
    local ok,hour=pcall(function() return gameTime and gameTime:getWorldAgeHours() end)
    if store and ok and hour then
        local stepped,err=pcall(demandScheduler.step,store,hour,demandScheduler.DEFAULT_BUDGET)
        if not stepped and print then print("[B47ANCEDWaterworks] Scheduled demand step failed safely: "..tostring(err)) end
    end
end
if Events and Events.EveryTenMinutes then Events.EveryTenMinutes.Add(processDemands) end
local function processLeaks()
    local store=registry.getStore();local gameTime=type(getGameTime)=="function"and getGameTime()or nil
    local ok,hour=pcall(function()return gameTime and gameTime:getWorldAgeHours()end)
    if store and ok and hour then
        local stepped,err=pcall(condition.step,store,hour,condition.DEFAULT_BUDGET)
        if not stepped and print then print("[B47ANCEDWaterworks] Leak step failed safely: "..tostring(err))end
    end
end
if Events and Events.EveryTenMinutes then Events.EveryTenMinutes.Add(processLeaks) end
local function processThermal()
    local store=registry.getStore();local gameTime=type(getGameTime)=="function"and getGameTime()or nil
    local ok,hour=pcall(function()return gameTime and gameTime:getWorldAgeHours()end)
    if store and ok and hour then
        local stepped,err=pcall(thermal.step,store,hour,thermal.DEFAULT_BUDGET)
        if not stepped and print then print("[B47ANCEDWaterworks] Thermal step failed safely: "..tostring(err))end
    end
end
if Events and Events.EveryTenMinutes then Events.EveryTenMinutes.Add(processThermal) end
require "waterWorks/CommandServer"
require "waterWorks/SamplingServer"
