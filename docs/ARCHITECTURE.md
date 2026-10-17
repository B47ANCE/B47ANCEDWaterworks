# B47ANCE’d Waterworks Architecture

## Ownership

B47ANCE’d Waterworks owns generic fluid-container adaptation, authoritative transfer,
water-quality state, mixing rules, persistence, and its public integration API.
Consumers own domain effects such as thirst, crop health, medical outcomes, or
electrical pump demand.

## Current runtime

shared/waterWorks/API.lua exposes the container and quality API. getContainer adapts Build 42
FluidContainer owners first, legacy water owners second, then registered
third-party adapters in stable identifier order. transfer validates authority,
capacity, vanilla compatibility, and destination persistence before mutation.
After the vanilla transfer succeeds it stores volume-weighted quality and mirrors
unsafe states to the vanilla tainted-water flag.

Transfers lock both adapted owners, reject non-finite amounts and existing
recovery markers, then measure both native container deltas. A successful call
is accepted only when the source and target report the same positive movement.
Quality is mixed from that measured amount rather than the request. If quality
persistence/readback fails, B47ANCE’d Waterworks reverses the measured transfer and proves
both amounts plus prior quality. Unprovable outcomes persist matching recovery
records on both owners; inspectTransferRecovery and
resolveTransferRecovery clear only proven rolled-back or committed states.

Quality providers are priority-ordered definitions that infer initial quality
for otherwise-untracked vanilla or third-party sources. Once quality is stored,
the persistent value is authoritative. Treatment definitions validate and
transform quality without owning tools or timed actions; content integrations
remain responsible for consuming their inputs before calling the authoritative
API. The built-in boiled transform reduces biological contamination only—it
does not remove chemicals, salinity, sediment, or turbidity.

Quality values are normalized from 0 (clean) to 1 (maximal contamination) along
five independent axes: biological, particulate, chemical, salinity, and
turbidity. The schema is deliberately generic and does not prescribe gameplay
consequences.

inspectContainer reports only capabilities verified on the adapted object:
water-source status, water-only status, mixture state, locks, primary fluid,
owner class, capacity, amount, taint, and normalized quality. A feeding trough
remains a vanilla IsoFeedingTrough with its vanilla FluidContainer; B47ANCE’d Waterworks
labels that capability for animalWorks instead of introducing a competing
trough implementation.

## Network topology

shared/waterWorks/Network.lua owns the 0.3 topology foundation. Persistent
state contains only schema-versioned scalar node descriptions, symmetric edge
sets, and published component assignments; it never stores loaded world-object
references. Stable node IDs survive streaming while runtime attachment remains
a future adapter concern. Channels prevent unlike fluids from sharing an edge,
and a hard degree ceiling bounds the work associated with any one node.

Every graph mutation is authoritative, increments the network revision, and
invalidates the current topology result. Connected components rebuild in a
separate weak runtime job. stepTopology processes no more than its supplied
node-work budget, restarts after a revision change, and publishes the completed
component map atomically. Consumers receive topology pending instead of a
partial or stale connectivity answer.

## Persistence and runtime providers

Registry.lua attaches the schema-versioned network registry to the server's
ModData table during OnInitGlobalModData. Persistent state contains networks
and a stable node index only. Loaded engine objects live in weak runtime maps;
detaching an object on chunk unload preserves its node, while explicit
decommissionNode removes both identity and topology under server authority.
Provider classification is priority ordered, bounded to 64 definitions, and
isolates callback failures.

Infrastructure.lua owns semantic provider contracts for sources, storage,
fixtures, valves, pumps, junctions, treatment devices, and meters. Consumers
inspect normalized state or request a named action by stable node ID. The layer
rejects clients, unloaded nodes, malformed payloads, read-only providers, and
concurrent work on the same node. It never exposes persistent tables as a
mutation API.

VanillaProviders.lua adapts only world FluidContainer objects explicitly
claimed by an authoritative caller. It persists a versioned role/network marker
in the object's ModData, derives identity from verified coordinates, sprite, and
object index, and restores the runtime attachment from that marker. Capability
checks conservatively distinguish source, storage, and externally supplied
fixture roles. There is intentionally no global fixture scan and no automatic
ownership of every loaded water object.

Version 0.31.0 adds PlumbingConformance ahead of foreign provider
registration. A candidate must declare a canonical role, server authority, and
explicit claim/detach/decommission lifecycle, then pass one to 32 caller-owned
positive/negative fixtures. The harness calls classification and description
under containment, verifies repeatable explicit identity and role-appropriate
state fields, bounds diagnostics, and registers only a passing provider through
Infrastructure. It discovers nothing and contains no third-party identities.
Version 0.33.1 enforces the stated evidence boundary: at least one positive and
one negative fixture are required, so recognition alone cannot certify an
adapter whose exclusion behavior was never exercised.

Version 0.32.0 adds a reserved-drain transaction for cross-domain consumers.
Begin writes the operation marker before changing native volume and retains it
after verified deduction. Commit rechecks exact volume and unchanged quality;
rollback restores exact volume. A bounded committed-operation history makes
commit replay harmless. While reserved, transfer, treatment, direct quality
mutation, and another drain fail closed.

Version 0.33.0 adds FilterTransactions, the authority-owned bridge between
pure filter evaluation and physical provider-owned media. Reservations freeze a
bounded plan without mutating media. Commit re-resolves stable stage identities,
rejects changed state, verifies each capacity write, reverses completed earlier
stages after a clean later failure, and records any uncertain mutation for an
explicit accept-committed or restore-before recovery decision. It supplies no
media balance, recipes, or automatic object discovery.

## Connections and hydraulic planning

Connections.lua is the gameplay-facing topology mutation boundary. Both
endpoints must be loaded, belong to the same network and channel, lie within a
server-clamped separation, and remain within the acting character's reach.
Priority-ordered validators can enforce skills, tools, materials, permissions,
or ownership without duplicating graph logic. Edge locks prevent overlapping
connect/disconnect operations.

Hydraulics.lua incrementally samples normalized provider state per published
topology component. It reports supply, stored volume/capacity, demand, deficit,
supply ratio, pump power status, and a conservative pressure ceiling/estimate.
Discovery and inspection each consume caller-provided work units. Reports bind
to the exact network revision and disappear after topology changes. Pressure is
withheld when unloaded nodes, closed valves, or unknown pump power make the
estimate unreliable; this planner is not presented as a full fluid solver.

## Command transport

Commands.lua, CommandServer.lua, and CommandClient.lua provide the narrow
multiplayer transport for connection changes. The server accepts only known
commands and bounded string identifiers, obtains the actor from
OnClientCommand, reconstructs trusted reach limits, enforces a per-player
per-tick allowance, and caches 64 request IDs so retries cannot apply twice.
Successful changes return a targeted result and a sanitized delta; engine
objects and internal node tables never cross the wire. Failed requests are not
broadcast.

Initial snapshots require a loaded anchor node within server-defined range and
contain at most 64 nodes per page. Continuation requests bind to the same
network revision and opaque node cursor. The client accepts a continuation only
when its revision and cursor match the page currently expected; only a first
page can reset cached state. Successful deltas are sent solely to subscribers
still close to an affected endpoint. A server tick advances at most one dirty
network by 16 topology work units, preventing command-triggered rebuild spikes.

## Routed flow and pump power

Flow.lua validates source/target roles, shared network/channel ownership, and
an open loaded route before moving fluid. Its breadth-first route search stops
after 256 nodes. Optional minimum pressure is accepted only from a current,
reliable hydraulic report. The actual mutation delegates to API.transfer, so
measured native deltas, volume-weighted quality, locking, rollback, and recovery
quarantine remain single-owned. A successful flow invalidates its hydraulic
report.

PumpPower.lua is an optional provider adapter. A pump definition supplies its
powerWorks consumer, pressure, and demand; the adapter reads the canonical
getConsumerPowerState result. Known unpowered and unknown power remain distinct
states. powerWorks owns energy and batteries, while B47ANCE’d Waterworks owns pump and
flow semantics.

Version 0.10.0 extends that boundary with per-pump energyPerFluidUnit and the
canonical powerWorks energy transaction API. Routed flow reserves exact energy
for every powered pump on the validated route, performs the existing measured
fluid/quality transaction, then commits those reservations. A fluid failure
rolls all reservations back to their exact prior fractions. A post-fluid energy
commit that cannot be verified reports an explicit recovery-inspection result;
B47ANCE’d Waterworks never guesses that an already committed fluid mutation was reversed.

Version 0.11.0 adds the first-party portable transfer-pump definition and an
original provider adapter for a loaded placed object. The contained inventory
item is the canonical powerWorks consumer; the world wrapper supplies stable
network identity and coordinates. Vanilla 42.20.3 source inspection confirmed
that ordinary ISDropWorldItemAction does not emit OnObjectAdded for generic
items, so this adapter is not auto-wired to ordinary dropping. A dedicated
server-authoritative placement action must register the returned world object.

Version 0.12.0 supplies that explicit claim boundary. The client sends a bounded
request ID, item ID, and coordinates from the selected world object. The server
does not trust the object reference: it resolves the loaded square, searches at
most 128 world objects, verifies the exact item ID and first-party pump type,
checks actor reach, rate limits and deduplicates the request, and attaches the
resolved object through the registry. The context-menu callback is isolated from
broken third-party objects and never mutates topology locally.

Version 0.13.0 adds a bounded routed-flow command and the first player-facing
network workflow. The server caps requested volume, resolves both persistent
nodes, requires both loaded endpoints within interaction reach, deduplicates the
operation ID, and invokes Flow.transfer; retries cannot move fluid twice. The
client stores one endpoint selection per local player and queues a timed
connect, disconnect, or flow action against the second selected world object.
Movement interrupts the action, and completion revalidates the living actor,
both objects, reach, distinct node IDs, and one-shot send state.

## Scheduled demand

Version 0.14.0 stores schema-versioned demand definitions inside the persistent
registry using scalar IDs, timing, amount, pressure, counters, and last-error
data only. DemandScheduler.step advances a weak per-store cursor and inspects
no more than its explicit budget; it never scans every schedule in one event.
Due work delegates to Flow.transfer, so network routing, quality, locks,
rollback, and pump energy remain canonical. Both success and failure advance the
next run time to prevent a broken endpoint from retrying continuously. The
server invokes at most four entries every ten game minutes behind callback
containment.

## Treatment transactions and devices

Version 0.15.0 makes applyTreatment a recoverable transaction. It records the
prior quality and bounded history under a serializable operation marker, writes
the transformed quality, verifies read-back, appends an operation-tagged history
entry, and clears the marker only after success. Failure restores both quality
and history; an unprovable rollback remains quarantined for inspection.

TreatmentDevices.lua registers semantic treatment providers. A device must be
available on an open loaded route to a storage/fixture target. Its fixed and
per-fluid energy costs are reserved through powerWorks before mutation. Failed
treatment restores exact charge; successful treatment commits the reservation.
If energy commit cannot be proven after quality changed, the result explicitly
requires energy recovery inspection rather than reversing committed water state.

## Condition and leakage

Version 0.16.0 adds a canonical measured drain transaction for operations that
remove fluid without a destination. It uses the verified Build 42
FluidContainer.adjustAmount primitive, measures the result, restores the prior
amount on mismatch, and leaves a serializable inspection marker only when exact
rollback cannot be proven.

Condition.lua keeps schema-versioned condition and leak rates by persistent
node ID. Damage and repair are explicit authoritative mutations. Its scheduler
uses a weak per-store cursor, processes only its caller-supplied budget, caps
elapsed catch-up at 24 game hours, and drains only currently loaded objects
through the canonical API. Unloaded nodes retain their state and a compact error
rather than triggering a world scan or silently losing fluid.

## Thermal state and freezing

Version 0.17.0 stores temperature and frozen state by persistent node ID.
Thermal.step uses a weak cursor, caller budget, and 24-hour catch-up ceiling;
it samples only loaded nodes. The default ambient resolver calls the vanilla
42.20.3 getClimateManager():getTemperature() method confirmed in installed
game scripts. A provider may replace that resolver when it can prove a more
local temperature. Freeze at 0 C and thaw at 1 C provide hysteresis, and the
canonical route traversal rejects frozen nodes. Explicit authoritative heat
application changes the same state instead of bypassing it.

Version 0.18.0 replaces the hardcoded one-unit context action with a bounded
transfer submenu. The client may choose 1, 5, 10, 25, 50, or 100 units; that
amount remains part of the existing interruptible timed action and authoritative
flow request. Commands.MAX_FLOW_AMOUNT still caps the server at 100, and all
route, reach, pressure, capacity, energy, quality, rollback, and deduplication
rules remain canonical.

Version 0.22.0 adds a final custom entry to that submenu. The client accepts a
locale-friendly decimal only when it is finite and between 0.01 and 100 units,
then queues the same timed action. This is convenience validation, not an
authority boundary: the server still independently applies its canonical cap,
reach, route, pressure, capacity, power, quality, and deduplication rules.

Version 0.23.0 exposes recurring route configuration beside the selected
endpoint workflow. Two sequential bounded dialogs collect amount and interval;
they send no mutation themselves. The server resolves both persistent nodes,
requires both loaded endpoints within actor reach, previews the open role-valid
route, obtains authoritative world age, and creates or updates one schedule per
ordered source/target pair. Request IDs provide replay safety, update preserves
execution diagnostics, and cancellation repeats endpoint and reach validation.
The scheduler remains the only owner of recurring-flow persistence and cadence.

Version 0.19.0 adds a read-only inspection boundary over the persistent registry.
waterWorks.inspectNetworks returns deterministic cursor pages capped at 32
networks plus aggregate node, edge, component, dirty-topology, and error totals.
waterWorks.reportNetworks renders the same protected data under an 8 KB ceiling.
Malformed network inspection is isolated to its row and never mutates or repairs
authoritative state. A later UI may consume this API without traversing internals.

## World-object lifecycle

Version 0.20.0 wires the installed Build 42 LoadGridsquare, ReuseGridsquare,
OnObjectAdded, and OnObjectAboutToBeRemoved event contracts. Square callbacks
inspect only the supplied square's bounded object collections. Load/add callbacks
call Registry.reattachObject, which requires the provider-derived node identity
to exist already in the persistent registry; recognition alone cannot claim a
fixture or dropped pump. Reuse/removal callbacks clear only weak runtime bindings,
leaving topology and persistent identity intact for reload.

Native inspection confirmed that IsoChunk.doLoadGridsquare() fires
LoadGridsquare(square) after object world attachment and doReuseGridsquares()
fires ReuseGridsquare(square) before object reuse/reset. Explicit destruction or
relocation still requires an owning decommission/move transaction because the
generic removal event does not distinguish those outcomes from temporary removal.

The same release replaces every use of Lua's global next() with a shared
pairs()-based cursor adapter. Build 42 Kahlua does not expose next; host tests
execute affected schedulers and topology paths with next=nil.

## Player network inspection

Version 0.21.0 adds a read-only context action for an explicitly claimed loaded
endpoint. It sends the endpoint's provider-derived node and network IDs through
the existing subscription command. The server re-resolves the persistent node,
requires its runtime object to be loaded and the actor to remain within twelve
tiles, then returns at most 64 sanitized nodes per page.

The client accepts continuations only for the exact revision and expected opaque
cursor. It sends at most one continuation per tick, caps a session at 1,024
pages, terminates on an explicit server error, and never reads server registry
tables locally. The final modal escapes provider identifiers and displays no more
than 512 node rows while retaining full aggregate counts.

## Next boundaries

Version 0.28.0 adds Filters.lua, a generic provider boundary for filtration.
Definitions declare ownership, affected quality axes, nominal capacity, flow
restriction and replaceable-media semantics. Providers retain exact efficiency
and capacity-consumption policy through an isolated evaluator; B47ANCE’d Waterworks
normalizes its output and rejects undeclared quality mutation, contaminant
increases, capacity overdraft, and invalid flow. Evaluation is pure planning and
does not mutate water, media, or network state. A future physical filter device
must compose this plan with existing authoritative treatment, condition, and
flow transactions.

Version 0.29.0 closes the production-registration gap for that boundary. Both
client and server load graphs now initialize Filters.lua, and infrastructure
providers may use the documented filter role with normalized filter identity,
capacity, condition, replaceable-media, flow-multiplier, and exhaustion fields.
evaluateFilterChain applies no more than sixteen provider-owned definitions in
declared order and returns protected per-stage plans. It remains deliberately
non-mutating: physical devices must commit water and media state through a later
recoverable transaction rather than treating a successful preview as authority.

The first concrete treatment workflow is implemented in 0.24.0: a craftable
electric purifier registers as an explicitly claimed treatment node and applies
the canonical heat-sterilization transform through a server-authoritative,
power-backed transaction. Player-facing leak repair, powered heating, and water
sampling were the next boundaries at that point. The implemented repair,
heating, and sampling layers below build on the existing transfer, quality,
topology, registry, and infrastructure APIs rather than introducing parallel
state. Broader treatment content and dedicated-server validation remain future
work.

Version 0.25.0 adds two player-facing compositions of those ledgers. Connected
electric purifiers can apply bounded powered heat to an explicitly selected
storage/fixture endpoint. The route may terminate at a frozen target for thawing,
but frozen intermediate nodes remain non-traversable. Infrastructure patch kits
drive a timed repair command that resolves one exact owned item under a hard
inventory budget. The condition repair and resource removal are synchronous and
atomic on confirmed outcomes; an unprovable resource result preserves the
committed state in a bounded persistent quarantine instead of permitting replay.

Version 0.26.0 makes that quarantine operational rather than write-only.
Maintenance.listRecoveries returns deterministic cursor pages capped at 32
records, and authority may resolve an exact matching record by accepting the
committed repair or restoring the recorded prior condition/leak state. A changed
node cannot be resolved from stale evidence.

The same release adds FirstPartyValves.lua, a craftable placed inline-valve
provider. Its ModData stores only versioned network and open-state scalars;
opening and closing travels through Infrastructure.requestAction, with server
reach, rate, and request-replay validation. The existing flow traversal remains
the sole owner of closed-valve blocking.

Existing vanilla FluidContainer objects gain an explicit player claim command.
The client supplies coordinates, object index, and sprite as an assertion only.
The server reconstructs the loaded square, searches a bounded object list,
verifies the exact identity and FluidContainer capability, then delegates to
VanillaProviders.claimObject. No fixture is globally scanned or automatically
owned.

## Water sampling

Version 0.27.0 adds a read-only player knowledge boundary over the existing
water-quality ledger. Visual inspection reports only appearance, odor, visible
volume, and vanilla taint. A Water Test Kit reports categorical biological,
particulate, chemical, salinity, turbidity, treatment, and overall-state bands;
neither path exposes exact hidden quality values or mutates the sampled water.

The client identifies one loaded fixture by square, object index, and sprite, or
one dropped fluid item by square and exact item identity. After an interruptible
timed action, the server reconstructs that target, checks reach and non-empty
fluid capability, resolves an exact owned test kit through no more than 512
nested inventory entries, and consumes one verified reagent use. Request IDs
are replay-protected, results are explicitly sanitized, and no global world or
inventory scan is performed.

Sampling, action time, and contextual test-kit loot are independently bounded
by sandbox settings. Test kits use ten drainable reagent charges and are added
only to a small allowlist of medical, laboratory, pharmacy, hospital, and
camping containers.

## Current Power API resolution

Version 0.34.1 resolves the optional API dynamically as `B47ANCEDPower` first,
then `powerWorks`. Consumer registration, power-state inspection, routed fluid
transactions, treatment and heating use the same precedence. A known current
namespace is never replaced with legacy power merely because current power is
unknown or unpowered. Each operation retains its selected API locally for
reservation, commit and rollback. Battery metadata remains exclusively owned by
Power; Waterworks adds no migration or duplicate battery ledger.

No gameplay setting or state schema changes. Namespace selection is an internal
compatibility rule, not meaningful sandbox configuration. Server authority,
existing server sandbox values, vanilla fluid synchronization, replay protection,
join/reconnect and existing persistence contracts remain unchanged. Native
synchronization, servicing, save/reload and dedicated acceptance remain runtime
gates. See POWER_INTEGRATION.md.
