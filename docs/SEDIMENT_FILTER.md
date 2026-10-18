# Sediment filter housing

Current version: 0.35.1. Housing introduced in 0.35.0 (additive MINOR from 0.34.1).
The 0.35.1 patch changes thumbnail artwork and version metadata only.

[VERIFIED, source] Runtime is Lua-only. This is an explicit whole-container batch
filter, not automatic inline flow. Existing APIs, Mod ID, Workshop ID, registry
schema and old save namespaces are retained. No dependency on Power is added.

## Crafting and use

| Output | Consumed ingredients | Retained tool | Recipe time |
| --- | --- | --- | --- |
| waterWorks.SedimentFilterHousing | 2 Base.SmallSheetMetal, 2 Base.MetalPipe, 1 Base.DuctTape | Base.PipeWrench | 300 |
| waterWorks.SedimentFilterMedia | 1 full Base.Sandbag, 1 Base.Sheet | None | 180 |

The sandbag uses ItemCount/IsFull and destroy mode so crafting cannot obtain a
whole cartridge from a partial bag. These script definitions follow installed
Build 42 syntax; actual ingredient deductions and recipe discovery are NOT TESTED.
Native TirePump and SandBag visuals are placeholders, not new original assets.

Place/register the exact housing item, install a cartridge from owned inventory
(including nested bags), and connect it to a registered loaded water storage or
fixture. Select the housing or target with the existing endpoint menu, then use
the filtering action on the counterpart. Both endpoints must be within three
tiles of the living actor on the same floor, with an open loaded route.

The entire water-only container is treated in place. Capacity use equals measured
water volume; insufficient capacity rejects all work. Particulate and turbidity
are multiplied by 1 minus the configured removal fraction. Biology, chemical
contamination and salinity are unchanged; unsafe water stays tainted. Repeating
successful batches consumes capacity each time. No-removable-sediment and zero-
efficacy requests are rejected. Old media is discarded on replacement.

## Server sandbox configuration

| Stable waterWorks option | Default | Bounds / existing-save behavior |
| --- | --- | --- |
| EnableSedimentFilters | true | Disables new claims, installation and filtering; preserves records |
| SedimentMediaCapacity | 100 | 1..10000 fluid units; applied to newly installed cartridges only |
| SedimentRemovalFraction | 0.75 | 0..1; authoritative at each new batch |
| SedimentActionTimeMultiplier | 1 | 0.1..10; 120 base action units, presentation only |

Missing/non-finite numbers use defaults; finite values are clamped server-side.
Existing saves receive defaults without altering unrelated registry data. Time
is a local timed-action convenience, not server-enforced anti-cheat. Recipes and
resource identities are fixed content; bounded traversal, IDs, protocol lengths
and recovery/history ceilings are internal safety constants, not balance options.
English labels/tooltips are supplied; other locales use vanilla fallback and need
runtime confirmation. Failed intent receives localized generic failure feedback.

## Authority, persistence and recovery

Clients send action, exact world/item or registered node identity, media ID,
expected media generation and request ID. They cannot send capacity or quality.
The existing rate-limited server command cache resolves loaded objects, actor
identity/reach/floor and nested inventory ownership. Only the server removes one
exact cartridge using native inventory synchronization, assigns generation and
changes capacity or water. Request IDs are player-scoped; completed housing
operations retain bounded replay fingerprints. Replacement invalidates previous
stage generations so old reservations cannot charge new cartridges.

The server registry owns additive sedimentHousings schema 1: bounded identity
sequence, entries, item identity, coordinates, generation, capacity, remaining,
operation history and pending record. An item ModData token contains only schema
and housing key; world-object ModData is a read-only presentation projection.
Existing Lifecycle/Registry bindings restore only registered identities on load.
Weak references never constitute persistent authority. Native item/world ModData
save behavior and projection delivery to nearby/new clients remain runtime gates.

Installation persists pending state before removal. Verified rejected removal
clears it without refilling; uncertain removal/synchronization retains quarantine.
Filtering reserves and verifies physical media consumption, then uses the existing
quality transaction under an unforgeable Lua-local permit. Generic treatment
requests cannot apply the sediment transform for free. A proven unchanged/restored
water state permits exact committed-media compensation; all uncertain outcomes
keep consumed capacity and pending recovery. Interruptions during either phase
remain blocked on reload. No safe administrative resolution/reset API or UI for
housing pending records is implemented; do not clear or refund them automatically.
The generic media recovery API alone cannot bypass a housing quarantine.

Ordinary manual and scheduled routes reject batch filter nodes. The private batch
route exception permits only its source housing, never intermediate batch filters.
Explicit re-claim after runtime detach preserves identity/capacity; relocation
removes old connections before attaching at the new square. Simultaneous live
identity claims, malformed/future schemas, missing nodes and stale generations
fail closed. Decommissioned housing ledger entries are retained conservatively;
no destructive migration, garbage collection or backward downgrade is promised.

## Evidence and remaining gates

[VERIFIED, source] Installed Steam build 25485521; full engine version UNKNOWN.
Portable installed-source fingerprints and observed call limits are recorded in
api/sediment-25485521.json. The engine sources were read, never modified/copied.
Native inventory removal/synchronization, timed-action call form, full-bag recipe
flags, item/model IDs and translation key formats were inspected. Source evidence
alone does not prove native mutation or multiplayer delivery.

[TESTED, offline Windows / Lua 5.1 via lupa] See VALIDATION.md for exact commands.
Tests exercise nested owned media, replay/conflicts, expected generation, actor
reach/floor/death, capacity/axes, ordinary-flow exclusion, permit protection,
verified refund, uncertain quarantine, serialized-table reload and client denial.

[RUNTIME GATE] Native recipes and visuals, real nested inventory removal and peer
synchronization, tainted flag, exact volume/capacity, timed-action cancellation,
controller/UI scale/fallback text, chunk unload/relocation, old-save initialization,
join/rejoin, disconnect during install/filter, persistence and dedicated restart
are NOT TESTED. Use disposable saves; two clients must observe exactly one media
removal and consistent water/capacity after duplicate/racing commands. Change
sandbox defaults between reloads and verify existing media is not silently refilled.
G7 BLOCKED / NOT TESTED; stable-release G8 BLOCKED. No package/release, deploy,
Workshop upload, server/game launch or live-save edit is authorized by this work.
