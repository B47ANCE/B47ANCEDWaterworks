# B47ANCE’d Waterworks Persistence Schema Audit

This audit records the persistence behavior implemented by the current source. It is a compatibility contract, not a migration policy. No schema version is changed by this document.

## Global registry

- Owner: Registry.lua
- Storage: global ModData key waterWorks.NetworkRegistry.v1
- Current schema: schemaVersion = 1, revision, networks, and nodeIndex
- Creation seam: attachStore initializes only a table with no entries.
- Load behavior: current complete state attaches; malformed or non-current state is rejected without repair.
- Runtime-only state: loaded object references, reverse object lookup, provider definitions, and topology jobs are weak in-memory tables and are never serialized.

Each networks entry is a Network.lua schema-1 graph containing revision, degree limit, scalar node descriptions, adjacency, and published component state. Graph validation rejects non-current versions and malformed required tables/scalars. Registry validation also checks both directions of the node-index relationship. There is no implemented legacy graph migrator.

## Registry-owned subordinate ledgers

| Owner | Store field | Current marker | Missing-state behavior | Unsupported-state behavior |
|---|---|---|---|---|
| DemandScheduler.lua | scheduledDemands | schema 1 | Created on first scheduler access | Rejected without replacement |
| Condition.lua | infrastructureCondition | schema 1 | Created on first condition access | Rejected without replacement |
| Thermal.lua | thermalState | schema 1 | Created only by Thermal.set; read/step reject absence | Rejected without replacement |
| Maintenance.lua | infrastructureMaintenanceRecovery | unversioned map of schema-1 records | Created only when a repair first needs the registry | Malformed maps and non-current records are rejected without replacement |

The maintenance registry is intentionally documented as an unversioned outer map because that is the shipped representation. Each record carries schemaVersion = 1, operation and item identity, before/after condition and leak values, requiresInspection, and a reason. Introducing an outer wrapper or migrating older records requires an explicit future policy decision.

## Container ModData

API.lua owns these persistent keys on adapted container owners:

- waterWorksQuality.v1: normalized schema-1 biological, particulate, chemical, salinity, turbidity, and treatment values.
- waterWorksTreatmentRecovery.v1: schema-1 in-progress or inspection-required treatment record.
- waterWorksDrainRecovery.v1: schema-1 in-progress or inspection-required measured-drain record.
- waterWorksTransferRecovery.v1: paired schema-1 quarantine records on source and target.
- waterWorksTreatmentHistory: bounded operation history; the outer list currently has no schema marker.

Mutation APIs refuse new treatment, drain, or transfer work whenever the corresponding recovery key is present. Transfer recovery is cleared only after matching records and measured state prove committed or rolled-back status. Treatment and drain recovery currently expose inspection but no general administrative resolver; deciding how to resolve unprovable records is product/migration policy, not a mechanical audit change.

## First-party and vanilla placed-object state

- VanillaProviders.lua owns waterWorksInfrastructure.v1, a schema-1 marker containing network, stable identity, role, channel, and coordinates.
- FirstPartyValves.lua owns waterWorksInlineValve.v1, a schema-1 marker containing network and open state.
- First-party pump and purifier providers read their network/enabled settings from their placed object's ModData (waterWorksNetworkId, waterWorksPumpEnabled, and waterWorksTreatmentEnabled). These scalar fields currently have no containing schema marker.

Unknown or non-current claimed-object markers are not reinterpreted as current markers. Claim paths also refuse to overwrite an already-present vanilla marker. Changing the unversioned first-party device settings to a wrapped schema is a future migration-policy decision.

## Mechanical migration seams versus policy

Mechanically safe seams already exist at registry attachment, subordinate-ledger access, recovery inspection, and placed-object marker classification. Current code can identify missing, current, malformed, and non-current data at those boundaries.

No source establishes conversion rules for old or future schemas, defaults for malformed fields, retention periods, destructive quarantine cleanup, or downgrade support. Those choices remain blocked on an explicit migration policy. Until then, unsupported data fails closed and remains untouched so diagnostics or a later administrator tool can inspect it.

Diagnostics.inspectPersistence now provides that non-mutating server-side
inspection boundary for the registry, subordinate ledgers, and paged maintenance
records. Diagnostics.inspectObjectPersistence classifies the known container,
claim, valve, and unversioned first-party device fields on one explicitly supplied
object. Both return only bounded classifications, versions, and stable IDs; they
perform no world scan and expose no mutable persistent table. No remote command is
provided because the repository does not yet establish an administrator permission
policy for this data.

## Host proof and remaining runtime gates

tests/test_persistence_contract.lua verifies current empty-store initialization and non-destructive rejection of future/malformed registry, schedule, condition, thermal, and maintenance-recovery state. Existing registry, network, scheduler, condition, thermal, transaction, lifecycle, valve, fixture, pump, purifier, and maintenance cases exercise current schema behavior.

Host tests cannot certify engine serialization, save/load timing, chunk streaming, hosted multiplayer, or dedicated-server authority. Those remain in-game gates. No release-readiness claim follows from this audit.
