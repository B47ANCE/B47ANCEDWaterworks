# B47ANCE’d Waterworks Testing

Current version: 0.35.1.

The Power integration suite now runs without a synthetic `powerWorks` global.
Fixtures initialize battery state with the current Power API and inspect charge/
recovery through that API. Tests cover canonical API precedence, legacy fallback,
unknown/missing/late Power, real reserve/commit/rollback, and command replay.
See [POWER_INTEGRATION.md](POWER_INTEGRATION.md) and current validation.

The version-specific notes below are historical.

Version 0.34.0 renames the product and Mod ID while retaining legacy data/API
identifiers. See [VALIDATION.md](VALIDATION.md) for this iteration’s evidence;
older version-specific notes below remain historical.

Version 0.33.1 tightens EXT-04 conformance coverage: a provider cannot register
unless its explicit fixture set demonstrates both a recognized object and an
excluded object. Host tests verify positive-only evidence fails closed.

Version 0.33.0 host coverage proves bounded physical-filter reservation without
mutation, stable provider/stage identity, replay conflict rejection, verified
commit, commit replay, cancellation, reverse rollback after partial failure,
lock release after rejected multi-stage reservations, mutate-then-fail recovery
classification, explicit recovery acceptance, future-schema rejection, and
client-authority denial. Native objects, save/reload mid-operation, media
replacement, and dedicated-server recovery remain unverified.

Version 0.32.0 host coverage proves exact drain reservation, same-operation
replay, competing-mutation exclusion, verified rollback, commit, and commit
replay. Native save/reload during reservation, container removal, late join, and
dedicated recovery remain required before appliance content is release-ready.

Version 0.31.0 adds the EXT-04 foreign-plumbing conformance gate. Host coverage
proves passing explicit storage fixtures, deterministic identity, idempotent
registration, and rejection of broad classification, missing declared state,
unstable identity, client authority, and scan-based lifecycle claims. This does
not certify any named third-party mod: each adapter still needs clean-room
fixtures plus in-game claim, unload/reload, removal, save, late-join, dedicated,
capacity, quality, flow and conflict testing.

Version 0.30.2 adds explicit regressions that successful command and sampling
payloads contain no failure reason and that known filter lookups return no
unknown-definition error.

Version 0.30.1 adds independent sandbox controls for the complete infrastructure
context-action surface, read-only inspector, custom decimal amounts, and
recurring-transfer controls. Host coverage proves default-on compatibility,
independent inspection, preset preservation, hidden optional controls, unchanged
endpoint selection, and consistent pump, purifier, valve, fixture-registration,
and repair-menu suppression.
Disabling the recurring-transfer UI intentionally does not cancel persisted
schedules; test that boundary in game before release.

Version 0.29.0 loads the filtration API in both production realms, recognizes
the documented filter infrastructure role, normalizes its public state, and
adds bounded sequential filter-chain evaluation. Host coverage proves the
sixteen-stage ceiling, ordered quality composition, protected results, exact
stage failure reporting, and absence of partial plans.

Version 0.28.1 adds an executable client/server production load-graph regression.
It fails when an implemented bootstrap dependency is omitted or loaded twice and
stubs the server lifecycle/schedulers without invoking engine callbacks.

Version 0.27.0 adds tiered visual inspection and reagent-backed water sampling
without revealing exact hidden quality values. Version 0.26.0 adds paged
repair-recovery resolution, craftable inline valves,
authoritative valve toggles, and exact vanilla-fixture registration. Version
0.25.0 added replay-safe powered heating and atomic patch-kit repairs, including
confirmed rollback and uncertain-outcome quarantine. Version 0.24.0
added first-party electric-purifier content, exact placed-device
claiming, and server-authoritative selected-route heat sterilization. Version
0.23.0 added recurring-transfer configuration.
Version 0.22.0 added validated custom decimal transfer entry. Version 0.21.0
added a bounded player-facing network inspector. Version 0.20.0
added verified world-object lifecycle wiring and removed all runtime
dependence on Kahlua's unavailable global next(). Version 0.19.0 added bounded
network inspection diagnostics alongside the 0.18.0 routed-transfer volume
choices. Verify every preset and valid custom amount queues the displayed amount,
comma decimals normalize correctly, invalid/non-finite/out-of-range input queues
nothing, action time scales with volume, interruption sends nothing, and server
validation still rejects amounts above 100 or beyond source/capacity limits.

Run the standalone host suite (optional Power integration requires `--power-root`):

powershell
python scripts/run_lua_tests.py


The persistence-contract case inventories the current global registry,
subordinate ledgers, recovery maps, and placed-object markers. It proves that
future or malformed registry, schedule, condition, thermal, and maintenance
recovery values are rejected without being replaced or mutated. See
PERSISTENCE_SCHEMA_AUDIT.md for the remaining migration-policy and in-game
save/load boundaries.

The diagnostics case also proves bounded, deterministic persistence-administration
paging; classification of missing, missing-version, malformed, legacy/future, and
current records; targeted object-marker inspection; client rejection; and exact
non-mutation of unsupported state. Remote administration remains intentionally
absent until a permission contract is established.

The B47ANCE’d Waterworks host case validates container adaptation, priority-based quality
inference, conservative boiling, treatment history, volume-weighted mixing,
tainted-water compatibility, transfer atomicity preflight, and legacy adapters.
It also covers non-finite input rejection, measured transfer operation IDs,
asymmetric native mutation quarantine, paired recovery inspection, conservative
resolution, and denial of new work while either container is quarantined.

The topology case validates authority checks, stable node validation, maximum
degree and fluid-channel isolation, explicit one-unit rebuild budgets,
split/merge results, mutation during an active rebuild, stale-job rejection,
neighbor queries, inspection counts, and malformed persistent state.

Before a gameplay release, test inventory and world FluidContainer transfers,
partial transfers, full destinations, rejected fluid mixtures, tainted-state
updates, save/load persistence, and client/server behavior in a dedicated
multiplayer session. Do not claim multiplayer support until that pass succeeds.

Also validate network save/reload, chunk unload/reload attachment, and remote
client mutation commands once world-event and command adapters are introduced.
The registry tests currently prove persistent identity across explicit
detach/reattach, weak runtime references, identity-conflict rejection, explicit
decommissioning, provider-failure isolation, normalized infrastructure state,
action validation, authority, and node locking. They do not prove that a
particular Build 42 chunk event fires with the required lifecycle semantics.

The vanilla-provider case proves explicit claims, persisted ModData markers,
source/fixture inference, normalized live capacity and amount, duplicate-claim
rejection, rollback on failed attachment, reload reattachment, and client denial.
In game, verify object index stability across save/reload and object-list changes
before treating the derived key as release-certified.

Connection tests cover loaded endpoint requirements, same-network/channel
ownership, server-clamped node spacing, actor reach, permission validators,
duplicates, missing edges, disconnection, and client rejection. Hydraulic tests
prove strict per-step budgets, per-component supply/storage/demand aggregation,
powered-pump pressure contribution, atomic report publication, and invalidation
after topology mutation.

Command tests cover module/command allowlisting, bounded request identifiers,
server-owned actor context, successful targeted replies and deltas, idempotent
request replay, no repeated graph mutation, and removal of runtime/internal
tables before serialization. Dedicated-server timing and overload behavior still
require an in-game multiplayer pass.

Snapshot tests cover nearby loaded-anchor authorization, exact-revision paging,
subscriber-only deltas, bounded topology maintenance, client page assembly, and
rejection of mixed-revision continuations. Multiplayer testing must still prove
actual event signatures, packet ordering, disconnect cleanup, and behavior with
multiple clients moving in and out of relevance range.

Flow tests cover role validation, bounded loaded-route discovery, closed-valve
blocking, optional pressure requirements, native measured transfer delegation,
quality-compatible results, route length, hydraulic invalidation, and client
denial. Pump tests preserve the distinction between powered, known unpowered,
and unknown powerWorks state. Cross-domain tests use the real powerWorks API to
prove successful flow consumes exact pump energy and rejected native fluid work
restores the pre-operation charge without leaving a recovery marker.

The first-party pump test verifies consumer registration, stable placed-object
identity, network selection, empty/charged power state, pump pressure/flow
metadata, and canonical consumer recovery. Runtime placement remains an in-game
gate because vanilla's generic item-drop action does not emit OnObjectAdded.

Placement-command tests cover server square lookup, exact item-ID/type checks,
actor reach, missing-item rejection, sanitized replies, and replay without a
second registry mutation. Client menu tests cover duplicate selections, icons,
payload construction, and callback containment for throwing mod objects.

Flow-command tests prove transfer caps, endpoint existence, actor reach,
successful measured movement, and replay without a second transfer. Timed-action
tests prove endpoint and death revalidation, movement interruption settings,
volume-scaled duration, and one-shot command sending. Two-step menu tests cover
selection, clear, connect, disconnect, preset and custom-decimal flow, invalid
bounds, and unknown-object isolation.

Demand-scheduler tests cover serializable creation, authority, validation,
one-entry work budgets, cursor continuation, due-time execution, success/failure
counters, retry advancement, history-preserving updates, compact inspection,
and cancellation. Command/dialog tests cover decimal parsing, bounded intervals,
loaded endpoint and actor-reach checks, role-valid preview, authoritative world
time, pair updates, idempotent replay, and cancellation of an exact pair. Runtime
world-time event cadence and save/reload remain in-game gates.

Treatment tests inject a quality read-back mismatch and prove exact quality plus
history rollback and marker clearance. Device tests cover open-route targeting,
registered treatment selection, exact power reservation/commit, and verified
energy rollback when treatment fails. Save/reload recovery and real powered
device world objects remain in-game gates.

Drain tests prove measured removal, rejection of a native no-op, exact rollback,
and recovery-marker clearance. Condition tests cover persistent setup, bounded
hourly leakage, damage, repair, unloaded-node containment, and client rejection.
Real FluidContainer drain behavior, save/reload, and long-running event cadence
remain in-game gates.

Thermal tests prove bounded ambient convergence, freezing at the threshold,
route rejection, explicit thawing, restored traversal, and client mutation
denial. In-game testing must verify server climate availability, indoor/local
temperature limitations, event cadence, and persistence across save/reload.

Lifecycle host tests prove bounded collection traversal, duplicate suppression,
existing-node-only reattachment, runtime-only detach, idempotent event install,
and callback failure containment. In game, claim a fixture and portable pump,
leave/re-enter the chunk, move far enough to force square reuse, and save/reload;
the attached count must fall and recover while node IDs and edges remain stable.
Removing an unclaimed object must never create a node. Inspect console.txt for
Lifecycle callback failed safely and any attempted call to global next.

Right-click a claimed loaded endpoint and choose **Inspect Water Network**. A
nearby actor should receive a role/component/connection summary. Verify networks
over 64 nodes page without a frame spike, topology changes reject mixed pages,
moving beyond twelve tiles rejects a fresh request, provider text cannot inject
rich-text tags, and multiple clients see only snapshots authorized through their
own loaded nearby anchors.

Valve tests cover stable placed identity, condition-derived flow metadata,
persistent open/closed state, closed-route behavior through the canonical flow
planner, exact item claim, actor reach, request replay, and nil-safe context
callbacks. In game, craft and place a valve, register it, connect it between two
loaded endpoints, and verify closing it blocks both manual and scheduled flow
until reopened. Save/reload and chunk-stream the valve in each state.

Fixture claim tests reconstruct the exact server square, object index, and
sprite and reject spoofed identities before calling the existing conservative
vanilla provider. In game, register sinks, rain collectors, storage tanks, and
externally supplied fixtures; verify their inferred roles, stable IDs after
reload, and that an unregistered or unsupported object never enters the graph.

Maintenance-recovery tests page bounded records, reject invalid cursors, retain
the committed repair when accepted, and restore the exact recorded condition
and leak values when requested. Dedicated-server administration UI for these
operations remains an in-game validation gate.

Sampling tests cover the visual-versus-kit disclosure boundary, empty and
unsupported targets, categorical quality bands, explicit treatment reporting,
exact loaded-fixture and dropped-item reconstruction, reach validation, bounded
nested-kit lookup, one verified reagent use, replay protection, sanitized
responses, client formatting, timed-action interruption, nil-safe context-menu
construction, sandbox controls, and contextual loot insertion.

In game, inspect clear, cloudy, tainted, treated, saline, and chemically unsafe
water with and without a Water Test Kit. Confirm visual inspection never claims
invisible contamination is absent, a successful kit test consumes exactly one
of ten uses even when the kit is nested, moving away or cancelling consumes
nothing, and repeating one request cannot consume twice. Repeat against loaded
fixtures and dropped fluid items, across save/reload, with a remote client, and
with sampling disabled. Inspect console.txt for B47ANCE’d Waterworks errors after each
case.

## Sediment housing acceptance (0.35.0)

[TESTED, offline Windows] 54 cases PASS with Power; 48 standalone PASS and six
optional-Power skips. Three sediment cases cover shared state, server commands
and client presentation/action intent; filter transaction tests add committed-media
compensation and stale-state rejection. All 48 runtime Lua files compile as Lua 5.1.

[RUNTIME GATE] Follow SEDIMENT_FILTER.md with disposable saves. Craft both recipes;
verify full-bag destruction and exact ingredient deductions, nested cartridge
removal on server and both clients, cancellation/moving/death, generic failure
feedback, water quality/taint and no volume change. Repeat racing requests with
two clients; test insufficient/exhausted capacity, disabled settings, relocation,
chunk reuse, old-save initialization, restart and client join/rejoin. Confirm
quarantine never resets/refills during interruption and full cartridges remain
unchanged when capacity defaults change. Test English fallback, controller and
UI scale. Native art is a placeholder. Timed duration is presentation, not
server anti-cheat. G7/stable G8 remain BLOCKED until dedicated evidence exists.
