# B47ANCE’d Waterworks Roadmap

> Consolidated status: [MASTER_ROADMAP.md](MASTER_ROADMAP.md).

## Implemented foundation

- Build 42 and legacy water-container adapters.
- Measured authoritative transfers with rollback and recovery quarantine.
- Persistent multi-axis quality, mixing, providers, and treatment transforms.
- Serializable fluid-network nodes and edges with bounded degree and channels.
- Incremental, revision-safe connected-component rebuilding under caller budget.
- GlobalModData-ready registry with persistent identity and weak runtime attachment.
- Semantic source, storage, fixture, valve, pump, junction, treatment, and meter providers.
- Explicit vanilla world-FluidContainer claiming and reload attachment.
- Server-validated physical connection/deconnection workflow.
- Bounded per-component capacity, supply, demand, deficit, pump, and pressure planning.
- Bounded, deduplicated server command routing and sanitized connection deltas.
- Anchor-authorized paged snapshots and relevance-filtered delta subscriptions.
- One-network-per-tick bounded topology maintenance.
- Bounded open-route validation and real measured source-to-target transactions.
- Optional powerWorks-backed pump-state provider contract.
- Recoverable reserve-fluid-commit transactions with per-pump energy cost.
- First-party portable pump item and stable placed-object/powerWorks adapter.
- Explicit server-authoritative placed-pump claim command and world context action.
- Timed two-endpoint connect/disconnect/routed-flow world workflow.
- Persistent budgeted scheduled demands using canonical routed transfers.
- Recoverable quality-treatment transactions and powerWorks-backed treatment-device API.
- Recoverable measured drain transactions with inspection markers.
- Persistent infrastructure condition, damage, repair, and budgeted loaded-node leaks.
- Persistent bounded temperature convergence, freeze/thaw hysteresis, and frozen-route blocking.
- Player-facing bounded routed-transfer volume choices using the existing timed,
  server-authoritative flow command.
- Bounded cursor-paged network inspection snapshots and text diagnostics with
  aggregate topology health and isolated malformed-network reporting.
- Verified Build 42 lifecycle wiring for square load/reuse and object add/remove;
  it automatically restores only already-persisted nodes and preserves graph
  identity when runtime objects unload.
- Kahlua-compatible cursor traversal across every bounded runtime scheduler and
  page builder; no release path depends on the unavailable global next().
- Player-facing network inspection from a selected loaded endpoint. The client
  assembles server-authorized, revision-locked 64-node pages at one continuation
  per tick and presents bounded role, component, connection, and node summaries.
- Optional custom routed-transfer entry accepts validated decimal amounts from
  0.01 through the canonical 100-unit server cap before queuing the timed action.
- Player-facing scheduled-demand configuration creates, updates, or cancels a
  recurring selected route through bounded, idempotent server commands. Updates
  preserve execution/failure history and reset the next run deterministically.
- Craftable portable pump and electric water purifier content with native
  condition/servicing tags and powerWorks cell profiles.
- Exact placed-purifier claiming and a player-facing selected-route
  heat-sterilization action. The server revalidates both endpoints, actor reach,
  treatment identity, open routing, power reservation, and canonical quality.
- Powered selected-route heating through the existing thermal state and
  powerWorks transaction, with bounded heat requests and replay-safe commands.
- Craftable patch kits, timed world repair actions, exact bounded nested-
  inventory resolution, atomic condition/resource commit, rollback, and
  bounded uncertain-outcome quarantine.
- Cursor-paged maintenance-recovery inspection with conservative authority-only
  accept-committed or restore-recorded-condition resolution.
- Craftable inline shutoff valves with persistent state, authoritative toggles,
  and canonical closed-route blocking.
- Explicit player-facing vanilla FluidContainer registration with exact
  server-side square, object-index, sprite, reach, rate, and replay validation.
- Tiered water sampling: free visual/smell inspection, consumable ten-use Water
  Test Kits, categorical quality results, bounded authoritative target and kit
  resolution, configurable timing/loot/enablement, and rare contextual loot.
- Client and server production bootstraps are covered by an executable load-graph
  regression, including filtration, lifecycle, and bounded scheduler
  dependencies (0.29.0).
- Filter providers have a canonical infrastructure role and normalized semantic
  state. Bounded filter chains evaluate up to sixteen provider-owned stages in
  order and fail without returning a partial plan.
- Player-facing infrastructure context actions, read-only network inspection,
  custom transfer amounts, and recurring-transfer controls have independent
  default-on sandbox switches. The master action control consistently covers
  endpoint, pump, purifier, valve, fixture-registration, and repair menus.
  Hiding controls preserves selections, networks, existing schedules, and the
  public API (0.30.1).

## Next vertical slices

1. The generic filter-definition/evaluation contract, production load graph,
   semantic infrastructure role, and bounded chain planner are implemented with
   provider-owned treatment math, declared contaminant axes, capacity,
   condition, flow and protected queries. Recoverable physical capacity commits
   and the 0.35.0 craftable sediment batch housing/cartridges are implemented in
   source. Native crafting, balance, additional media types, automatic inline
   treatment and dedicated validation remain future work.
2. Define migration policy and an authenticated remote-administration contract.
   Read-only server-side persistence inspection is implemented; migration,
   repair/reset, and remote permissions remain deliberately unspecified.
3. Stress testing and dedicated-server validation.

B47ANCE’d Waterworks remains water-focused. Its internal channel boundary prevents invalid
mixing and leaves room for third-party fluids without claiming fuel simulation.

## Approved external-research additions

- **EXT-04 — Plumbing conformance suite:** version 0.31.0 host-implements the
  bounded pre-registration gate for explicit foreign sources, sinks, storage,
  fixtures, valves, pumps, collectors, treatment devices, filters, meters and
  junctions. Stable identity, role state, server authority, negative fixtures,
  and claim/detach/decommission lifecycle are mandatory. Named third-party
  adapters remain separate clean-room slices and require native fixtures; no
  sprite scan or automatic adoption is permitted.
- **EXT-07 — Appliance consumers:** provide existing reserve/commit/rollback
  fluid transactions to foodWorks-owned appliance actions. Version 0.32.0 adds
  exact drain reservation, commit, rollback, replay and inspection; B47ANCE’d Waterworks
  does not own recipes, appliance UI, or power demand.
- **EXT-09 consumer:** preservation processes may request measured water through
  canonical transactions; no implicit or partial consumption is allowed.
- **EXT-14 feasibility:** participate only in basement drainage/plumbing proof
  after groundWorks establishes a valid topology and lifecycle model.
