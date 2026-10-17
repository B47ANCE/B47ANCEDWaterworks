isClient=function()return false end
dofile(arg[1])
local network=dofile(arg[2])
local registry=dofile(arg[3])
dofile(arg[4])
local condition=dofile(arg[5])
local thermal=dofile(arg[6])
local scheduler=dofile(arg[7])
local maintenance=dofile(arg[8])

local empty={}
assert(registry.attachStore(empty) and empty.schemaVersion==1,"an absent registry schema has an explicit creation seam")

local future={schemaVersion=99,revision=7,networks={},nodeIndex={}}
local beforeRevision=future.revision
assert(registry.attachStore(future)==false and future.schemaVersion==99 and future.revision==beforeRevision,
    "future registry data must be rejected without mutation")

local malformed={schemaVersion=1,revision=2,networks="broken",nodeIndex={}}
assert(registry.attachStore(malformed)==false and malformed.networks=="broken",
    "malformed registry data must remain available for inspection")

local store=registry.newStore()
store.scheduledDemands={schemaVersion=99,revision=3,entries={sentinel=true}}
local futureSchedule=store.scheduledDemands
assert(scheduler.inspect(store)==nil and store.scheduledDemands==futureSchedule
    and store.scheduledDemands.entries.sentinel==true,"future schedules must fail closed without replacement")

store.infrastructureCondition={schemaVersion=99,revision=4,entries={sentinel=true}}
local futureCondition=store.infrastructureCondition
assert(condition.inspect(store,"missing")==nil and store.infrastructureCondition==futureCondition
    and store.infrastructureCondition.entries.sentinel==true,"future condition state must fail closed without replacement")

store.thermalState={schemaVersion=99,revision=5,entries={sentinel=true}}
local futureThermal=store.thermalState
assert(thermal.inspect(store,"missing")==nil and store.thermalState==futureThermal
    and store.thermalState.entries.sentinel==true,"future thermal state must fail closed without replacement")

store.infrastructureMaintenanceRecovery="preserve-me"
assert(maintenance.listRecoveries(store)==nil and store.infrastructureMaintenanceRecovery=="preserve-me",
    "malformed maintenance recovery state must not be silently erased")
assert(maintenance.resolveRecovery(store,"node","acceptCommitted")==false
    and store.infrastructureMaintenanceRecovery=="preserve-me","resolution must fail closed on malformed recovery state")

local futureRecord={schemaVersion=99,requiresInspection=true,operationId="future"}
store.infrastructureMaintenanceRecovery={node=futureRecord}
assert(maintenance.inspectRecovery(store,"node")==nil and store.infrastructureMaintenanceRecovery.node==futureRecord,
    "future maintenance recovery records must remain untouched")

print("B47ANCEDWaterworks persistence schema compatibility checks passed")
