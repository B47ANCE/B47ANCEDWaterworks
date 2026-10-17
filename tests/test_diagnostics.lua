isClient=function() return false end
local Network=dofile(arg[1]); local Registry=dofile(arg[2]); local Diagnostics=dofile(arg[3])
local store=Registry.newStore(); Registry.Providers.test={id="test"}
for index=1,40 do
    local id=string.format("network-%02d",index); local state=Network.newState()
    assert(Network.addNode(state,{id=id..":node",kind="fixture",channel="WATER"}))
    while state.topologyDirty do assert(Network.stepTopology(state,8)) end
    store.networks[id]=state; store.nodeIndex[id..":node"]={networkId=id,providerId="test",stableKey=id}
end
local first=assert(Diagnostics.inspect(store,{limit=7}))
assert(#first.networks==7 and first.nextCursor==7 and first.totalNetworks==40)
assert(first.networks[1].id=="network-01" and first.totals.nodes==40)
store.infrastructureMaintenanceRecovery={pipe={requiresInspection=true}}
assert(Diagnostics.inspect(store,{limit=1}).totals.maintenanceRecoveries==1)
local second=assert(Diagnostics.inspect(store,{cursor=first.nextCursor,limit=1000}))
assert(#second.networks==32 and second.nextCursor==39,"page size must remain hard bounded")
local text,snapshot=Diagnostics.report(store,{limit=2})
assert(type(text)=="string" and #text<=Diagnostics.MAX_TEXT and #snapshot.networks==2)
first.networks[1].id="mutated"; assert(Diagnostics.inspect(store,{limit=1}).networks[1].id=="network-01")

store.scheduledDemands={schemaVersion=99,entries={}}
store.infrastructureCondition={entries={}}
store.thermalState="broken"
store.infrastructureMaintenanceRecovery={
    ["node-b"]={schemaVersion=99,requiresInspection=true},
    ["node-a"]={schemaVersion=1,requiresInspection=true},
}
local futureSchedule=store.scheduledDemands
local persistence=assert(Diagnostics.inspectPersistence(store,{limit=1}))
assert(persistence.registry.status=="current"and persistence.ledgers[1].status=="future-version"
    and persistence.ledgers[2].status=="missing-version"and persistence.ledgers[3].status=="malformed")
assert(persistence.maintenanceRecovery.status=="mixed-unsupported"and persistence.maintenanceRecovery.count==2
    and #persistence.maintenanceRecovery.records==1 and persistence.maintenanceRecovery.records[1].id=="node-a"
    and persistence.maintenanceRecovery.nextCursor==1)
assert(store.scheduledDemands==futureSchedule and store.infrastructureMaintenanceRecovery["node-b"].schemaVersion==99,
    "persistence inspection must not mutate unsupported data")

local owner={data={}}
function owner:getModData()return self.data end
owner.data["waterWorksQuality.v1"]={schemaVersion=1}
owner.data["waterWorksDrainRecovery.v1"]={schemaVersion=4}
owner.data.waterWorksPumpEnabled=true
local objectReport=assert(Diagnostics.inspectObjectPersistence(owner))
assert(objectReport.records[1].status=="current"and objectReport.records[3].status=="future-version")
assert(objectReport.records[8].id=="waterWorksPumpEnabled"and objectReport.records[8].status=="unversioned-present")

isClient=function()return true end
assert(Diagnostics.inspectPersistence(store)==nil and Diagnostics.inspectObjectPersistence(owner)==nil,
    "persistence administration must remain server-authority only")
print("B47ANCEDWaterworks bounded network diagnostic checks passed")
