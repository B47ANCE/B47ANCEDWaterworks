local clientModules={
    "waterWorks/API","waterWorks/Filters","waterWorks/FilterTransactions","waterWorks/Network","waterWorks/Registry",
    "waterWorks/Infrastructure","waterWorks/VanillaProviders","waterWorks/Connections",
    "waterWorks/Hydraulics","waterWorks/Flow","waterWorks/PumpPower",
    "waterWorks/FirstPartyPumps","waterWorks/TreatmentDevices","waterWorks/FirstPartyTreatment",
    "waterWorks/FirstPartyValves","waterWorks/FirstPartySediment","waterWorks/DemandScheduler","waterWorks/Condition",
    "waterWorks/Maintenance","waterWorks/Thermal","waterWorks/Commands",
    "waterWorks/Diagnostics","waterWorks/Sampling","waterWorks/CommandClient",
    "waterWorks/SamplingClient","waterWorks/NetworkInspector","waterWorks/DemandDialog",
    "waterWorks/NetworkTimedAction","waterWorks/PumpContextMenu",
    "waterWorks/TreatmentContextMenu","waterWorks/ValveContextMenu",
    "waterWorks/FixtureContextMenu","waterWorks/MaintenanceAction",
    "waterWorks/MaintenanceContextMenu","waterWorks/SamplingAction",
    "waterWorks/SamplingContextMenu","waterWorks/NetworkContextMenu",
    "waterWorks/SedimentAction","waterWorks/SedimentContextMenu",
}

local serverModules={
    "waterWorks/API","waterWorks/Filters","waterWorks/FilterTransactions","waterWorks/Network","waterWorks/Registry",
    "waterWorks/Infrastructure","waterWorks/VanillaProviders","waterWorks/Connections",
    "waterWorks/Hydraulics","waterWorks/Flow","waterWorks/PumpPower",
    "waterWorks/FirstPartyPumps","waterWorks/TreatmentDevices","waterWorks/FirstPartyTreatment",
    "waterWorks/FirstPartyValves","waterWorks/FirstPartySediment","waterWorks/DemandScheduler","waterWorks/Condition",
    "waterWorks/Maintenance","waterWorks/Thermal","waterWorks/Commands",
    "waterWorks/Diagnostics","waterWorks/Sampling","waterWorks/SamplingDistribution",
    "waterWorks/Lifecycle","waterWorks/CommandServer","waterWorks/SamplingServer",
}

local function stubFor(name)
    if name=="waterWorks/Registry" then return {STORE_KEY="waterWorksNetworks"} end
    if name=="waterWorks/DemandScheduler" or name=="waterWorks/Condition"
        or name=="waterWorks/Thermal" then
        return {DEFAULT_BUDGET=1,step=function() return true end}
    end
    if name=="waterWorks/Lifecycle" then return {install=function() return true end} end
    return {}
end

local function exercise(path,modules)
    local loaded={}
    for _,name in ipairs(modules) do
        package.loaded[name]=nil
        package.preload[name]=function()
            loaded[name]=(loaded[name] or 0)+1
            return stubFor(name)
        end
    end
    local previousEvents=rawget(_G,"Events")
    Events={
        OnInitGlobalModData={Add=function() end},
        EveryTenMinutes={Add=function() end},
    }
    dofile(path)
    Events=previousEvents
    for _,name in ipairs(modules) do
        assert(loaded[name]==1,"production loader omitted or duplicated "..name)
        package.preload[name]=nil
        package.loaded[name]=nil
    end
end

exercise(arg[1],clientModules)
exercise(arg[2],serverModules)

print("B47ANCEDWaterworks client/server production load-graph checks passed")
