# B47ANCE’d Waterworks

B47ANCE’d Waterworks is the generic water and fluid-infrastructure provider for the Works
ecosystem. Its first foundation extends Build 42 fluid containers with safe,
authoritative transfer and persistent multi-axis water quality metadata.

- Version: 0.35.2 foundation (not yet a gameplay release).
- Hard dependencies: none beyond Project Zomboid.
- Optional integrations: B47ANCE’d Power (`B47ANCEDPower`, with legacy `powerWorks` fallback) and lightWorks.

## Sediment filter workflow (0.35.0)

Craft a Sediment Filter Housing from two small metal sheets, two metal pipes
and one duct tape, using a retained pipe wrench. Craft each Sediment Filter
Cartridge from one full sandbag and one sheet. Place the housing, right-click to
register it, install a cartridge, and connect it to a registered water storage
container or fixture using the existing endpoint actions. Select either endpoint,
then choose the sediment filtering action on its connected counterpart.

Filtering treats the entire connected container in place. A cartridge handles
100 fluid units by default and each batch reduces particulate and turbidity by
75%; biological, chemical and salt hazards remain. Insufficient capacity rejects
the whole batch. Replace a used cartridge to refill capacity; old media is discarded.
Ordinary transfers cannot route through this batch device. No electricity is needed.

Four server sandbox options control enablement, capacity, removal and action time.
See [filter design and configuration](docs/SEDIMENT_FILTER.md). Recipes, native
inventory synchronization, visuals, SP and dedicated behavior await runtime tests.
English is supplied with vanilla fallback for other locales. Vanilla pump/sandbag
art is a placeholder. No deployment or Workshop upload accompanies this change.

## Current foundation

- reserves and commits bounded physical filter-media capacity through
  provider-owned identities, verifies every mutation, rolls back partial chains,
  and retains uncertain outcomes for explicit recovery resolution;

- exposes replay-safe drain reservation, commit, rollback, and inspection for
  cross-domain appliance operations while excluding competing transfer,
  treatment, and quality mutation on reserved fluid;

- provides an explicit foreign-plumbing conformance gate for stable identity,
  server authority, declared role/state, positive and negative fixtures, and
  claim/detach/decommission lifecycle semantics; it never scans or auto-claims
  foreign objects;

- exposes independent, default-on sandbox controls for all water-infrastructure
  context actions, the read-only network inspector, custom transfer amounts,
  and recurring-transfer controls without deleting persisted state or disabling
  public APIs;

- verifies the complete client/server production bootstrap graph in host tests,
  including lifecycle and bounded scheduler dependencies;

- adapts Build 42 FluidContainer objects and legacy water containers;
- performs server-authoritative transfers through verified vanilla primitives;
- tracks biological, particulate, chemical, salinity, and turbidity quality;
- volume-weights quality when fluids mix;
- mirrors unsafe quality to vanilla tainted-water behavior;
- supports priority-ordered source-quality providers and treatment transforms;
- provides conservative boiling semantics and bounded treatment history;
- reports normalized container capabilities for inventories, fixtures, natural
  sources, rain collectors, wells, and vanilla animal trough integrations;
- supports registered third-party container adapters.
- measures actual source/destination deltas after native transfers, rolls back
  failed quality commits, and quarantines unprovable outcomes for inspection.
- provides a serializable, server-authoritative fluid-network graph with stable
  node IDs, typed channels, bounded node degree, and atomic split/merge results;
- rebuilds connected components incrementally under an explicit work budget and
  discards stale jobs whenever topology changes during a rebuild.
- persists networks in an attachable registry while keeping loaded world objects
  in weak runtime maps so chunk unload never destroys infrastructure identity;
- exposes normalized source, storage, fixture, valve, pump, junction, treatment,
  filter, and meter provider contracts with authoritative, locked semantic
  actions.
- provides an explicit vanilla world-FluidContainer claim/reattach adapter that
  persists role and network identity without scanning or auto-owning fixtures.
- validates gameplay connection changes against loaded endpoints, network and
  channel identity, physical separation, actor reach, and bounded validators;
- incrementally publishes per-component supply, storage, demand, deficit, pump
  status, and conservative pressure estimates under explicit work budgets.
- routes multiplayer connection requests through a bounded server handler with
  strict payload validation, per-tick limits, request deduplication, targeted
  results, and sanitized successful-operation deltas.
- pages initial network snapshots at 64 nodes, requires a nearby loaded anchor,
  filters deltas to still-relevant subscribers, and rejects mixed revisions;
- advances one dirty network per tick with a fixed topology-work budget.
- performs real source-to-target transactions only through an open, loaded,
  role-valid route found within a hard 256-node search ceiling;
- optionally requires verified hydraulic pressure and consumes the existing
  measured transfer/quality rollback contract rather than mutating fluid twice;
- lets pump providers obtain known powered/unpowered state from powerWorks while
  keeping unknown power distinct and preserving B47ANCE’d Waterworks ownership of flow.
- composes pump energy and fluid movement as one recoverable cross-domain
  operation: reserve exact energy, perform measured fluid transfer, then commit;
  failed fluid work restores every earlier pump reservation.
- defines the first-party portable transfer pump item and a stable placed-object
  provider backed by a rechargeable powerWorks pack;
- exposes a nil-safe world action that asks the server to claim an exact placed
  pump; the server resolves its item ID on the asserted square, enforces actor
  reach, rate limits and deduplicates requests, then attaches it authoritatively.
- provides a two-step world workflow for selecting infrastructure endpoints and
  queuing timed connect, disconnect, or one-unit routed-transfer requests;
  completion revalidates the living actor and both endpoints before sending.
- persists bounded scheduled demands that execute through the same routed flow
  transaction, advance on success or failure, retain compact diagnostics, and
  process no more than four schedules per ten-game-minute server event.
- lets players create, update, or cancel a recurring transfer for the currently
  selected source/target route; the server re-resolves loaded endpoints, reach,
  route roles, amount, interval, world time, replay identity, and persistence.
- applies quality treatments as recoverable transactions and lets registered
  treatment devices reserve power, verify an open route, transform a connected
  container, then commit energy—or restore it exactly if treatment fails.
- performs measured, recoverable single-container drains through the same
  FluidContainer authority boundary, with rollback verification and quarantine;
- persists bounded per-node condition and leak state, supports explicit damage
  and repair operations, and advances loaded leaks under a fixed server budget.
- persists per-node fluid temperature, advances bounded loaded-node convergence
  toward the verified vanilla climate temperature, and blocks flow through
  frozen nodes until hysteresis-safe thawing or explicit heat application.
- provides bounded 1/5/10/25/50/100-unit transfer choices through the existing
  timed network action while retaining the canonical server-side 100-unit cap.
- provides an optional player-entered transfer amount from 0.01 through 100
  units, with decimal validation before the same timed authoritative action.
- exposes bounded, cursor-paged network diagnostics with aggregate topology
  health and protected text/snapshot reports for future inspection UI.
- restores already-claimed infrastructure through verified Build 42 square-load
  and object-add events, and releases weak runtime bindings on square reuse or
  object removal without deleting persistent network identity;
- uses a Kahlua-compatible bounded cursor iterator throughout topology,
  hydraulics, schedules, leakage, thermal state, snapshots, and maintenance.
- provides a nearby-endpoint network inspector assembled from bounded,
  server-authorized, revision-locked snapshot pages rather than local internals.
- adds a craftable, condition-aware electric water purifier backed by a
  powerWorks pack, exact placed-item registration, and an open-route
  heat-sterilization action with server-owned reach, replay, power, and quality
  transactions.
- adds routed powered heating through the canonical thermal ledger, including a
  frozen-target exception that does not make frozen intermediate pipes flowable;
- adds craftable infrastructure patch kits and timed player repairs whose exact
  inventory resource removal and condition/leak mutation commit atomically or
  leave a bounded recovery quarantine when the outcome cannot be proven.
- exposes cursor-paged maintenance-recovery inspection and conservative
  authority-only resolution as either a proven committed repair or an exact
  restoration of the recorded prior condition and leak state;
- adds a craftable inline shutoff valve with persistent open/closed state,
  server-authoritative reach/replay validation, and canonical route blocking;
- lets players explicitly register an exact loaded vanilla FluidContainer
  fixture. The server reconstructs its square, object index, and sprite before
  assigning its conservative source/storage/fixture role.
- lets players visually inspect non-empty loaded water sources without exposing
  exact hidden contamination, or consume one use of a Water Test Kit for
  categorical biological, particulate, chemical, salinity, and turbidity
  results. The server reconstructs the exact world target and owned nested kit,
  deduplicates requests, and returns only a sanitized report.
- loads the filtration API in both production realms and evaluates up to sixteen
  provider-owned filter stages in order without mutating water or media. Chain
  failures identify the exact stage and return no partial plan.

See [docs/B42_API_RESEARCH_HANDOFF.md](docs/B42_API_RESEARCH_HANDOFF.md) for the Build 42 FluidContainer research record. Planned gameplay systems remain gated behind focused technical spikes and tests.
- Non-goals: animal thirst, crop effects, medicine, and electricity generation.

Assets are staged under Contents/mods/B47ANCEDWaterworks/: Steam and in-game thumbnail.png at
the mod root, referenced by poster=thumbnail.png, with icon.png under 42/.
Thumbnail artwork adopted in 0.35.1 uses the user-supplied 1254x1254 image in both
[preview.png](preview.png) and the mod thumbnail, copied without alteration.
Version 0.35.2 installs the approved transparent, text-free barrel/faucet/wrench
cutout as 42/icon.png. Its original RGBA bytes and authoring master/prompt are
preserved under assets/artwork/. Both thumbnail files remain byte-for-byte
unchanged. Previous artwork is retained under
assets/artwork/history/; [artwork provenance](docs/artwork-provenance.json)
binds current hashes and historical locations. In-game display and Workshop
upload acceptance are NOT TESTED; distribution requires the explicit publishing
workflow and successful SteamCMD authentication.


## Project identity and compatibility

Display name: **B47ANCE’d Waterworks**. Mod ID: `B47ANCEDWaterworks`.
Existing Workshop item: `3788594390`. Canonical version: root `VERSION`.
Authoritative source: `Contents/mods/B47ANCEDWaterworks/`; `dist/` is historical.

The former Mod ID was `waterWorks`. Update enabled-mod lists and dependency
declarations to `B47ANCEDWaterworks`; never enable old and new copies together.
The established `waterWorks` Lua API, `waterWorks/*` imports, item types, sandbox
identifiers, network commands and persisted keys remain compatibility contracts.
New consumers may use `require "B47ANCEDWaterworks/API"` or the
`B47ANCEDWaterworks` global; both refer to the same API table.

See [rename compatibility](docs/RENAMING.md), [version policy](docs/VERSION_POLICY.md),
and [validation](docs/VALIDATION.md). Source checks: `python scripts/check_versions.py`;
`python scripts/run_lua_tests.py`; `python scripts/validate.py`.
Public source: [B47ANCE/B47ANCEDWaterworks](https://github.com/B47ANCE/B47ANCEDWaterworks).
The initial source import is merged on main; development uses feature branches and PR review.
See [GitHub workflow](GITHUB_ONBOARDING.md). SP/dedicated NOT TESTED;
G7 BLOCKED / NOT TESTED and stable-release G8 BLOCKED.

## Power integration

Powered pumps, purification and heating now prefer the current `B47ANCEDPower`
API and retain the legacy `powerWorks` fallback. Waterworks never rewrites
Power-owned battery or recovery records. See [the integration contract and
validation](docs/POWER_INTEGRATION.md). The 0.35.0 offline suite passes all 54
cases with the actual Power source; native SP/dedicated behavior remains untested.

## Workshop preparation

`python scripts/prepare_workshop.py --mp-testing --output-root <local-Workshop/_steamcmd>`
creates a new package, stage, manifest and VDF for existing item 3788594390 from
clean committed source. It never signs in, uploads, deploys or restarts Steam.
Use the verified local authoring folder, outside the source repository. See
[preparation and distribution gates](docs/WORKSHOP_PUBLISHING.md). Stable-release
G8 remains blocked; preparation is only for a labelled MP testing build.
