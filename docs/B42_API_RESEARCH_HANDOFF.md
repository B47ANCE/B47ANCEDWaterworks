# waterWorks — PROJECT ZOMBOID BUILD 42 WATER/FLUID API DEEP-DIVE
# Research, Feasibility Matrix, Architecture & Development Roadmap

TARGET:
Project Zomboid Build 42.x, with current stable runtime/repository treated as
the final source of truth.

PROJECT:
waterWorks

MISSION:
Turn Project Zomboid's existing water/fluid primitives into a comprehensive
water infrastructure framework.

waterWorks should improve and connect what vanilla already does rather than
replace Build 42's FluidContainer system.

======================================================================
0. FUNDAMENTAL DISCOVERY
======================================================================

Build 42 substantially changed the correct architecture for a water mod.

B41-era architecture often treated water as:

    item uses
    waterAmount
    taintedWater boolean
    special-case rain barrels

B42 introduces a component-oriented fluid system centered around FluidContainer.

Therefore:

DO NOT BUILD waterWorks AS A PARALLEL LIQUID SYSTEM.

BUILD waterWorks ON TOP OF B42 FLUIDCONTAINER.

Canonical rule:

B42 FluidContainer
        ↓
waterWorks adapters/framework
        ↓
collection
storage
plumbing
pressure
pumping
filtration
treatment
quality
distribution
consumers

======================================================================
1. IMPLEMENTATION CONFIDENCE CLASSIFICATION
======================================================================

Every proposed feature must be classified:

CONFIRMED
    Verified in installed/current B42 runtime or existing production-quality
    B42 implementation.

HIGH
    Public/runtime API strongly supports it, but prototype required.

EXPERIMENTAL
    Technically plausible but engine/runtime behavior requires proof.

BLOCKED
    Cannot currently be implemented cleanly.

UNVERIFIED
    Evidence exists but current stable behavior must be checked.

IMPORTANT:

JAVA METHOD EXISTS
!=
LUA METHOD VERIFIED

and:

OLD B41 WATER API
!=
CORRECT B42 IMPLEMENTATION.

Codex must inspect the installed current B42 files before finalizing production
architecture.

======================================================================
2. PRIMARY B42 FLUID SYSTEM
======================================================================

Research identifies:

zombie.entity.components.fluids

and specifically:

FluidContainer
FluidType

as central B42 concepts.

Current B42 Lua demonstrates patterns such as:

    item:hasComponent(ComponentType.FluidContainer)

    local fc = item:getFluidContainer()

    fc:getAmount()

    fc:getCapacity()

    fc:getPrimaryFluid()

    fc:isMixture()

    fc:contains(fluid)

This is the preferred foundation.

Do not use DrainableComboItem as the canonical waterWorks liquid abstraction.

Legacy drainables may require adapters.

======================================================================
3. WORLD FLUID CONTAINERS
======================================================================

Current API surfaces on IsoObject / IsoWorldInventoryObject include concepts
such as:

    getFluidAmount()
    getFluidCapacity()
    emptyFluid()
    useFluid(amount)
    addFluid(type, amount)

    canTransferFluidFrom(container)
    canTransferFluidTo(container)

    transferFluidFrom(container, amount)
    transferFluidTo(container, amount)

    hasWater()
    isPureWater(...)
    isTaintedWater()

    isFluidInputLocked()

This is an extremely strong foundation.

waterWorks should provide adapters rather than rewriting these mechanics.

======================================================================
4. LEGACY WATER API
======================================================================

IsoObject also exposes older/generic water concepts including:

    getWaterAmount()
    setWaterAmount()
    getWaterMax()
    useWater()
    hasWater()

    isTaintedWater()
    setTaintedWater()

    FindWaterSourceOnSquare()

    FindExternalWaterSource()
    hasExternalWaterSource()
    getUsesExternalWaterSource()
    setUsesExternalWaterSource()

These are important for compatibility with:

- legacy vanilla objects;
- fixtures;
- existing plumbing;
- older mods.

waterWorks should normalize both systems behind adapters.

Do NOT make consumers determine which generation of water API an object uses.

======================================================================
5. PROPOSED waterWorks ADAPTER LAYER
======================================================================

Conceptually:

waterWorks.SourceAdapter

Implementations:

    FluidContainerAdapter
    LegacyWaterObjectAdapter
    NaturalWaterAdapter
    PlumbingFixtureAdapter
    RainCollectorAdapter
    WellAdapter
    FeedingTroughAdapter
    PortableContainerAdapter
    VehicleTankAdapter
    CustomProviderAdapter

Consumer API:

    waterWorks.getContainer(object)

rather than:

    if object:getFluidContainer() then ...
    elseif object:getWaterAmount() then ...

Centralize B42 compatibility complexity.

======================================================================
6. VANILLA WATER SOURCES
======================================================================

waterWorks should identify/adapt vanilla sources including:

- municipal taps;
- sinks;
- toilets;
- bathtubs;
- showers where applicable;
- rain collectors;
- wells;
- rivers;
- lakes;
- ponds/natural water;
- world containers;
- portable containers;
- animal troughs;
- other FluidContainer entities.

Do not assume all sources behave identically.

======================================================================
7. MUNICIPAL WATER
======================================================================

Vanilla already provides pre-shutoff municipal water.

waterWorks should preserve vanilla behavior.

Potential extension:

waterWorks municipal-provider abstraction:

    MunicipalWaterProvider

State:

    available
    pressure
    quality
    shutoffState

Do NOT simulate an entire municipal water utility initially.

Vanilla should remain authoritative for normal world-water shutoff unless
waterWorks deliberately overrides it through a documented sandbox feature.

======================================================================
8. POST-SHUTOFF WATER
======================================================================

Vanilla fixtures can retain/use water according to vanilla mechanics.

waterWorks can improve the abstraction by distinguishing:

    municipal supply
    local fixture reserve
    plumbed storage
    pumped storage
    natural source

This enables better diagnostics:

    SINK
    Source: Roof Tank
    Pressure: Gravity
    Available: 84 L
    Quality: Untreated Rainwater

instead of merely:

    Water available.

======================================================================
9. NATURAL WATER
======================================================================

IsoGridSquare exposes water geometry information, and IsoObject provides water
source lookup primitives.

waterWorks should adapt:

- rivers;
- lakes;
- ponds;
- other natural sources.

Do not replace vanilla world-water rendering.

IsoWater is primarily a rendering/environment system and should not become the
waterWorks gameplay model.

======================================================================
10. WATER QUALITY: VANILLA BASELINE
======================================================================

Vanilla historically uses a relatively coarse distinction centered around:

    potable/clean
    tainted

B42's FluidContainer system provides richer fluid identity and mixture
capabilities, but does not appear to provide the full water-quality simulation
waterWorks wants.

Therefore waterWorks should ADD semantic quality metadata.

Do not replace fluid identity.

======================================================================
11. waterWorks QUALITY MODEL
======================================================================

Proposed model:

WaterQuality {
    biologicalContamination
    particulateContamination
    chemicalContamination
    salinity
    turbidity
    treatmentState
}

Potential normalized values:

    0.0 - 1.0

or appropriate discrete levels.

Derived state:

    POTABLE
    QUESTIONABLE
    UNSAFE
    SEVERELY_CONTAMINATED

IMPORTANT:

Keep this model understandable.

Do not create laboratory-grade chemistry simulation merely because possible.

======================================================================
12. VANILLA TAINTED-WATER COMPATIBILITY
======================================================================

waterWorks must remain compatible with vanilla:

    isTaintedWater()

Conceptually:

waterWorks detailed quality
        ↓
derive vanilla compatibility state
        ↓
isTaintedWater

If waterWorks says water is unsafe:

vanilla systems should also treat it as tainted where possible.

Avoid situations where:

waterWorks UI:
    contaminated

Vanilla:
    perfectly safe

======================================================================
13. FLUID MIXTURES
======================================================================

B42 FluidContainer supports mixtures.

This is extremely valuable.

waterWorks should NOT prevent B42 fluid mixing.

Examples:

fresh water + tainted water
rainwater + clean water
water + other fluid

waterWorks quality metadata must follow transfers/mixing.

Potential rule:

quality after mixing =
    volume-weighted source quality

with special rules for hazardous contaminants where needed.

======================================================================
14. CONTAMINATION SOURCES
======================================================================

waterWorks can introduce contamination pathways.

Potential biological:

- untreated natural water;
- dirty collection container;
- contaminated storage;
- unsafe plumbing;
- stagnant water.

Potential particulate:

- roof debris;
- dirt;
- sediment;
- rust.

Potential chemical:

- inappropriate container;
- fuel contamination;
- chemical contamination.

Do not make every source randomly dangerous.

Keep mechanics predictable and learnable.

======================================================================
15. RAINWATER
======================================================================

Vanilla B42 supports rain-catching FluidContainers.

The current simulation includes rain-catcher behavior.

Research indicates relevant container concepts include a RainFactor/rainCatcher
style property.

Vanilla rain intensity drives collection.

waterWorks should preserve vanilla rain filling whenever possible.

======================================================================
16. RAIN COLLECTORS
======================================================================

Vanilla currently has rain collectors.

waterWorks should improve:

- collection-area realism;
- gutter integration;
- lids;
- contamination;
- filtration;
- overflow;
- connections;
- storage networks;
- diagnostics.

Do not simply add twenty larger barrels.

The interesting gameplay is infrastructure.

======================================================================
17. RAIN COLLECTOR LIDS
======================================================================

Current B42 behavior/community testing indicates vanilla collectors can support
lid-related behavior affecting rain/contamination/evaporation.

Audit actual current implementation.

waterWorks should normalize:

OPEN:
    accepts rain
    exposed to contamination
    possible evaporation

CLOSED:
    no rain input
    reduced contamination
    reduced evaporation

If vanilla already implements behavior, adapt it rather than duplicate it.

======================================================================
18. GUTTERS
======================================================================

This is HIGHLY FEASIBLE.

Existing B42 implementation demonstrates that:

- vanilla rain collectors can be enhanced;
- roof area can influence collection;
- existing gutters can be recognized;
- player-built gutter networks can be modeled;
- generic FluidContainer objects can receive rain;
- MP support is achievable.

Therefore gutters are a core waterWorks feature.

======================================================================
19. GUTTER ARCHITECTURE
======================================================================

Concept:

RoofCatchment
    ↓
GutterNetwork
    ↓
Downspout
    ↓
Container / cistern

Rain yield:

precipitation
    ×
effective roof area
    ×
collection efficiency
    ×
loss factors

This is vastly more interesting than vanilla's:

container opening area
    ×
rain.

======================================================================
20. EXISTING BUILDING GUTTERS
======================================================================

Where map/building geometry permits:

waterWorks should recognize existing gutter/downspout structures.

Potential interaction:

Install Rain Diverter

or:

Connect Downspout

No need to rebuild an entire gutter system on houses that visually already have
one.

Requires robust sprite/building detection.

CLASSIFICATION:
HIGH/EXPERIMENTAL depending on map metadata.

======================================================================
21. PLAYER-BUILT GUTTERS
======================================================================

Add craftable:

- gutter section;
- corner;
- downspout;
- junction;
- rain diverter;
- leaf screen.

Potential materials:

- metal;
- improvised sheet metal;
- suitable scavenged materials.

waterWorks owns this system.

======================================================================
22. ROOF AREA CALCULATION
======================================================================

Do not calculate every roof tile every rain tick.

Cache roof catchments.

Recalculate only when:

- gutter network changes;
- building geometry changes;
- connected collector changes;
- relevant chunk loads.

Rain event then becomes:

cachedCatchmentArea × rainIntensity.

======================================================================
23. FIRST-FLUSH DIVERTER
======================================================================

Excellent waterWorks feature.

Real rain systems often discard the first portion of rainfall because it washes
roof contaminants into the system.

waterWorks can model:

Dry roof
    ↓
Rain starts
    ↓
First Flush Diverter fills
    ↓
dirty initial runoff discarded
    ↓
cleaner rain routed to storage

Optional/sandbox configurable.

This creates meaningful infrastructure progression.

======================================================================
24. LEAF / DEBRIS SCREENS
======================================================================

Gutter inlet screen:

reduces:
    leaves
    debris
    particulate contamination

Requires:
    occasional cleaning.

This provides maintenance without excessive complexity.

======================================================================
25. RAINWATER CONTAMINATION
======================================================================

Vanilla rainwater can remain compatible with tainted-water mechanics.

waterWorks can make quality depend on:

- roof collection;
- roof cleanliness;
- first-flush system;
- gutter condition;
- filter;
- storage condition;
- lid;
- stagnation.

Do not make rain magically clean merely because it passed through plumbing.

======================================================================
26. PLUMBING
======================================================================

Vanilla already has plumbing behavior and external-water-source concepts.

waterWorks should extend this rather than create context-menu hacks per fixture.

Desired abstraction:

Source
    ↓
Pipe Network
    ↓
Fixture

Network can include:

storage
pump
filter
valve
fixture

======================================================================
27. VANILLA PLUMBING ADAPTER
======================================================================

Maintain compatibility with normal:

- sink;
- toilet;
- bathtub;
- shower;
- other plumbable fixtures.

Existing vanilla behavior should continue functioning without requiring the
player to rebuild everything as waterWorks pipes.

waterWorks may internally create a virtual adapter network.

======================================================================
28. PLAYER-BUILT PIPE NETWORK
======================================================================

Major new feature.

Components:

- pipe;
- elbow;
- tee;
- valve;
- shutoff valve;
- manifold;
- hose connection;
- pump;
- filter housing;
- tank connection;
- fixture connection.

Potential materials:

- copper;
- steel/galvanized;
- PVC where period appropriate;
- improvised hose.

Do not simulate every centimeter of pipe.

Represent network topology logically.

======================================================================
29. NETWORK GRAPH
======================================================================

waterWorks plumbing should be a graph.

Nodes:

SOURCE
STORAGE
PUMP
FILTER
VALVE
FIXTURE
JUNCTION

Edges:

PIPE/Hose connection.

Example:

Rain Tank
   |
Valve
   |
Pump
   |
Sediment Filter
   |
Carbon Filter
   |
+------+------+
|             |
Sink        Shower

This architecture allows expansion without hard-coded fixture logic.

======================================================================
30. PRESSURE
======================================================================

Vanilla water availability is comparatively binary.

waterWorks can introduce useful pressure abstraction.

Pressure sources:

- municipal;
- gravity tank;
- pump;
- elevated tank.

Consumers can require:

NONE
LOW
NORMAL
HIGH

Do not implement computational fluid dynamics.

Use simplified network pressure.

======================================================================
31. GRAVITY-FED WATER
======================================================================

Elevation can matter.

Example:

roof tank
    ↓
sink below

works without electricity.

Tank on same/lower level:
    insufficient pressure for some fixtures.

This gives elevated tanks meaningful gameplay value.

CLASSIFICATION:
HIGH as custom network logic.

======================================================================
32. WATER PUMPS
======================================================================

Add:

- hand pump;
- electric transfer pump;
- well pump;
- pressure pump;
- sump pump where useful.

waterWorks owns hydraulic behavior.

powerWorks optionally owns electrical supply.

======================================================================
33. HAND PUMPS
======================================================================

No electricity required.

Possible applications:

- well;
- cistern;
- barrel transfer;
- shallow groundwater system.

Player effort/time drives flow.

CLASSIFICATION:
HIGH.

======================================================================
34. ELECTRIC PUMPS
======================================================================

waterWorks:

pump curve abstraction
flow
pressure
water movement

powerWorks:

electricity availability
electrical load
faults/circuits

Example:

waterWorks Pump:
    requires 400 W

powerWorks:
    available.

waterWorks:
    network becomes pressurized.

======================================================================
35. PUMP POWER FAILURE
======================================================================

When electricity disappears:

pump stops.

But:

stored pressure / elevated tank may continue supplying water.

This creates interesting outage behavior.

======================================================================
36. PRESSURE TANKS
======================================================================

Potential:

pump
    ↓
pressure tank
    ↓
fixtures

Allows pump cycling rather than continuous operation.

Keep simulation coarse.

Useful primarily for immersion and powerWorks integration.

======================================================================
37. WELLS
======================================================================

Vanilla has wells/water sources.

waterWorks should adapt them.

Potential extensions:

- well depth abstraction;
- hand pump;
- powered pump;
- well contamination;
- maintenance;
- filtration.

Do not remove vanilla wells.

======================================================================
38. GROUNDWATER
======================================================================

Potential advanced feature:

Player-built wells.

Feasibility depends on map/environment information.

Simplified model:

eligible outdoor tile
    +
construction requirements
    +
depth/location rules
    ↓
groundwater source

Do NOT simulate a complete underground aquifer.

CLASSIFICATION:
EXPERIMENTAL/HIGH.

======================================================================
39. CISTERNS
======================================================================

Add large-capacity storage:

- plastic tank;
- steel tank;
- buried cistern;
- concrete cistern;
- improvised tank.

All should ultimately use/bridge FluidContainer.

waterWorks adds:

connections
quality
maintenance
network membership.

======================================================================
40. BARRELS
======================================================================

B42's FluidContainer system already makes barrels capable of storing different
liquids.

waterWorks should NOT hard-code every barrel as "water barrel."

Container compatibility should follow FluidContainer.

waterWorks adds water-specific behavior only when contents are water.

======================================================================
41. PORTABLE WATER CONTAINERS
======================================================================

Adapt B42 FluidContainer inventory items.

Examples:

- bottle;
- cooking pot;
- bucket;
- canteen;
- jug;
- kettle;
- improvised container.

waterWorks should not recreate these.

Potential additions:

- jerrycan rated for water;
- collapsible water carrier;
- large camping jug;
- hydration container.

======================================================================
42. GENERIC CONTAINER API
======================================================================

Earlier ecosystem decision remains:

waterWorks provides generic water-container APIs.

Example conceptual interface:

waterWorks.Containers.register(...)
waterWorks.Containers.get(...)
waterWorks.Containers.getCapacity(...)
waterWorks.Containers.getWater(...)
waterWorks.Containers.transfer(...)

animalWorks can consume this API.

waterWorks does NOT implement animal behavior.

======================================================================
43. VANILLA ANIMAL TROUGHS
======================================================================

IMPORTANT CORRECTION:

B42 includes IsoFeedingTrough.

API exposes concepts including:

    getWater()
    getMaxWater()
    checkWaterFromRain()
    createFluidContainer()
    linked animals

Therefore:

waterWorks should ADAPT vanilla troughs.

animalWorks owns:

- animal thirst;
- finding trough;
- drinking behavior;
- species needs.

waterWorks owns:

- trough water container compatibility;
- plumbing connection;
- filling;
- quality;
- network supply.

Do NOT add redundant waterWorks trough content unless there is a specific
infrastructure reason.

======================================================================
44. FILTERING
======================================================================

This is one of the largest vanilla gaps.

Create generic filter stages.

Concept:

waterWorks.FilterDefinition

properties:

    contaminantsRemoved
    efficiency
    capacity
    flowRestriction
    replaceableMedia
    condition

======================================================================
45. SEDIMENT FILTER
======================================================================

Removes:

- dirt;
- rust;
- suspended particles;
- roof debris.

Does NOT automatically sterilize biological contamination.

This distinction is important.

======================================================================
46. CLOTH / IMPROVISED FILTER
======================================================================

Early-game filtration.

Possible media:

- cloth;
- clean rag;
- layered fabric.

Reduces particulate contamination.

Does NOT make dangerous natural water reliably potable.

======================================================================
47. SAND FILTER
======================================================================

Craftable slow filtration.

Layers:

gravel
sand
charcoal where appropriate

Reduces:

- turbidity;
- particulate load;
- some contamination depending on balancing.

Do not make it a magical universal purifier.

======================================================================
48. ACTIVATED CARBON FILTER
======================================================================

Potential:

carbon cartridge
or
craftable activated-charcoal media.

Useful for:

- taste/odor abstraction;
- some chemical contamination;
- organic compounds.

Should NOT necessarily remove pathogens.

======================================================================
49. CERAMIC FILTER
======================================================================

Potential portable/base filter.

Strong biological/particulate filtration.

Requires:

- ceramic element;
- cleaning;
- eventual replacement/damage.

Historically appropriate.

======================================================================
50. WATER PURIFICATION TABLETS
======================================================================

Potential chemical treatment.

Examples conceptually:

- iodine;
- chlorine-based tablets.

Effect:

biological contamination reduction.

Possible:

taste penalty
treatment time.

medWorks may provide/own some pharmaceutical content if appropriate, but
waterWorks owns water treatment outcome.

======================================================================
51. BOILING
======================================================================

Vanilla already allows water purification through heating/boiling mechanics.

Do not replace vanilla cooking unnecessarily.

waterWorks should detect/adapt purified output.

Potential improvement:

waterWorks detailed contamination state should respond appropriately to boiling.

Boiling:

strong biological treatment.

Does NOT remove:

- sediment;
- salt;
- many chemical contaminants.

This is an important improvement over binary "tainted → clean."

======================================================================
52. DISTILLATION
======================================================================

Add advanced treatment.

Water
    ↓
boil
    ↓
steam
    ↓
condenser
    ↓
distilled water

Can remove:

- pathogens;
- salts;
- many particulates.

Some volatile chemicals may require special handling if modeled.

Potential equipment:

- improvised still;
- laboratory distiller;
- larger still.

CLASSIFICATION:
HIGH using crafting/fluid transfers.

======================================================================
53. UV-C PURIFICATION
======================================================================

Cross-project integration:

lightWorks owns:

    UV-C emitter
    UV output/exposure

waterWorks owns:

    water exposure chamber
    required dose
    treatment result

powerWorks optionally supplies electricity.

Flow:

powerWorks
    ↓
lightWorks UVC emitter
    ↓
waterWorks treatment chamber
    ↓
biological contamination reduced

Excellent theWorks ecosystem integration.

======================================================================
54. UV PURIFIER
======================================================================

Potential devices:

- portable UV purifier;
- inline UV sterilizer;
- larger base treatment unit.

Limitations:

UV works poorly through very turbid water.

Therefore:

sediment filtration
    ↓
UV treatment

should outperform:

muddy water
    ↓
UV.

This gives filter stages purpose.

======================================================================
55. CHLORINATION
======================================================================

Potential:

chlorine treatment.

waterWorks can support treatment dose/time.

Chemical source/content may come from vanilla or another crafting/chemistry
provider.

Avoid requiring a chemistry framework for basic waterWorks.

======================================================================
56. FILTER HOUSINGS
======================================================================

Inline plumbing component:

Pipe
    ↓
Filter Housing
    ↓
Pipe

Installed cartridge determines treatment.

Examples:

Sediment cartridge
Carbon cartridge
Ceramic cartridge

Filter state:

remainingCapacity
condition
clogging

======================================================================
57. FILTER CLOGGING
======================================================================

Dirty water should consume filter capacity faster.

Example:

clear rainwater:
slow clogging

muddy river water:
rapid clogging

This creates meaningful source/treatment decisions.

======================================================================
58. FLOW RESTRICTION
======================================================================

Dirty/clogged filters can reduce network flow.

Do not calculate real hydraulic resistance.

Simple:

flowMultiplier = filterCondition.

======================================================================
59. FILTER MAINTENANCE
======================================================================

Possible actions:

- replace cartridge;
- wash sediment filter;
- scrub ceramic filter;
- replace media;
- backwash large filter.

Use timed actions.

======================================================================
60. WATER TESTING
======================================================================

Add water testing.

Early:

visual/smell inspection

Later:

water test kit.

Potential displayed information:

Turbidity
Biological risk
Chemical risk
Salinity
Treatment state

Do not reveal exact hidden values without appropriate equipment/skill.

======================================================================
61. WATER QUALITY UI
======================================================================

Example:

RAIN TANK
Capacity: 500 L
Stored: 327 L

Quality:
    Biological: Moderate
    Sediment: Low
    Chemical: None

Treatment:
    First Flush
    Sediment Filter

Potability:
    Unsafe to Drink

Connections:
    Kitchen
    Shower
    Garden

======================================================================
62. STORAGE CONTAMINATION
======================================================================

Potential factors:

- open lid;
- dirty container;
- long-term stagnation;
- mixed contaminated water;
- damaged tank.

Keep update intervals coarse.

No need to evaluate every tank every tick.

======================================================================
63. STAGNATION
======================================================================

Optional/sandbox feature.

Long-stored untreated water can gradually become biologically unsafe.

Affected by:

- sealed state;
- initial treatment;
- temperature if available;
- container cleanliness.

Do not make this excessively punishing by default.

======================================================================
64. CONTAINER CLEANLINESS
======================================================================

A container previously storing:

gasoline
chemicals
dirty liquid

should not instantly become a perfect potable-water tank.

B42 mixtures may already help represent this.

waterWorks can additionally track cleanliness/residue if necessary.

Prototype first.

======================================================================
65. CROSS-CONTAMINATION
======================================================================

Fluid transfer should propagate quality.

Never:

dirty source
    ↓
clean tank
    =
clean water

Transfer/mixing hooks must update waterWorks quality metadata.

======================================================================
66. WATER TEMPERATURE
======================================================================

Possible future metadata:

cold
ambient
hot
boiling.

Do not build custom thermodynamics unless vanilla fluid/food temperature APIs
provide value.

Potential uses:

- showers;
- boiling;
- freezing;
- industrial treatment.

CLASSIFICATION:
FUTURE/VERIFY.

======================================================================
67. HOT WATER
======================================================================

Potential advanced infrastructure:

cold supply
    ↓
water heater
    ↓
hot-water line
    ↓
sink/shower

Power source:

electric
or
fuel-fired.

This is technically plausible but not first-release priority.

waterWorks owns water/heater behavior.

powerWorks owns electrical supply.

======================================================================
68. SHOWERS
======================================================================

Potential improvement:

actual plumbed shower usage consuming network water.

Possible factors:

flow rate
available pressure
water temperature

medWorks may care about hygiene consequences.

waterWorks owns water consumption.

======================================================================
69. TOILETS
======================================================================

Potential:

toilet tank consumes water when flushed.

After municipal shutdown:

can refill manually
or
from waterWorks network.

Do not overbuild sewage yet.

Fresh-water supply and wastewater are separate domains.

======================================================================
70. WASTEWATER
======================================================================

Potential future waterWorks subsystem:

graywater
blackwater

However this dramatically expands scope.

Initial waterWorks should focus on supply/treatment.

Architecture should avoid making wastewater impossible later.

======================================================================
71. GRAYWATER
======================================================================

Future possibility:

sink/shower discharge
    ↓
graywater tank
    ↓
non-potable uses

Possible:

- toilet flushing;
- irrigation.

farmWorks can consume irrigation water.

CLASSIFICATION:
FUTURE/HIGH conceptually.

======================================================================
72. SEWAGE
======================================================================

Full sewage/septic simulation should NOT be initial scope.

Possible later:

- septic tank;
- sewer connection;
- waste contamination.

Keep interfaces extensible.

======================================================================
73. IRRIGATION
======================================================================

waterWorks should provide water delivery API.

farmWorks owns crop behavior.

waterWorks:

tank
pump
pipe
valve
irrigation outlet

farmWorks:

soil moisture
crop water demand
sprinkler/drip effect.

Do not put crop simulation in waterWorks.

======================================================================
74. SPRINKLERS
======================================================================

waterWorks may own the physical irrigation emitter/device:

- sprinkler;
- hose;
- drip outlet.

farmWorks consumes emitted irrigation.

Exact ownership should follow established rule:

waterWorks owns water transport/output.
farmWorks owns agricultural consequence.

======================================================================
75. HOSES
======================================================================

Add flexible hose connections.

Potential:

- tank filling;
- pump transfer;
- irrigation;
- vehicle tank;
- temporary plumbing.

Network edge type:

HOSE

Properties:

length
condition
flow limit.

CLASSIFICATION:
HIGH.

======================================================================
76. FIRE-FIGHTING WATER
======================================================================

Potential future consumer:

hose/flooding/fire suppression.

waterWorks can provide:

pressure
flow
available water.

Fire system owns extinguishing outcome where possible.

Do not make waterWorks a fire overhaul.

======================================================================
77. PORTABLE PUMPS
======================================================================

Potential:

- hand transfer pump;
- electric utility pump;
- gasoline-powered pump if appropriate.

Can move:

natural source
    ↓
tank

or:

tank
    ↓
tank.

waterWorks owns fluid transfer.

Power/fuel provider owns energy.

======================================================================
78. VEHICLE WATER TANKS
======================================================================

B42's component/vehicle infrastructure may permit vehicle-mounted FluidContainer
style storage or custom adapters.

Potential:

- water tanker;
- trailer tank;
- utility tank;
- portable firefighting tank.

CLASSIFICATION:
HIGH/EXPERIMENTAL depending on entity-component integration.

Do not hard-code waterWorks around one vehicle mod.

Provide adapter API.

======================================================================
79. WATER TRAILERS
======================================================================

Excellent future animalWorks/vehicle ecosystem integration.

waterWorks owns:

tank
fluid
connections.

Vehicle framework owns:

movement.

animalWorks may provide:

animal-drawn water cart.

waterWorks should not care what moves the tank.

======================================================================
80. animalWorks INTEGRATION
======================================================================

animalWorks queries waterWorks:

    Can this object supply water?
    How much?
    What quality?
    Is it reachable?

animalWorks owns:

    animal thirst
    drinking
    species consumption
    behavior

waterWorks owns:

    water source/container/network.

Vanilla troughs should be supported through the same API.

======================================================================
81. farmWorks INTEGRATION
======================================================================

waterWorks provides:

- irrigation water;
- water quality;
- delivery rate;
- valves;
- pumps;
- tanks.

farmWorks provides:

- crop demand;
- soil moisture;
- irrigation effect;
- crop consequences.

======================================================================
82. medWorks INTEGRATION
======================================================================

waterWorks may expose:

    WaterQuality

medWorks can consume it for:

- drinking consequences;
- wound-cleaning suitability;
- hygiene consequences.

Do not put medical diagnosis/treatment inside waterWorks.

Vanilla poisoning effects should remain compatible.

======================================================================
83. lightWorks INTEGRATION
======================================================================

lightWorks provides:

    UV emitter
    UV-C dose

waterWorks provides:

    treatment chamber
    water exposure
    sterilization result.

No duplicate UV calculation.

======================================================================
84. powerWorks INTEGRATION
======================================================================

powerWorks supplies:

- pumps;
- UV purifier;
- water heater;
- powered treatment equipment.

waterWorks registers electrical loads.

Do not build electrical networks inside waterWorks.

======================================================================
85. RAIN / CLIMATE
======================================================================

Rain collection should consume vanilla climate/precipitation state.

Do NOT create waterWorks weather.

Potential modifiers:

rain intensity
snow
temperature
season

where useful.

======================================================================
86. SNOW
======================================================================

Current B42 fluid simulation appears to distinguish snow/rain behavior for
catchers.

Audit exact stable implementation.

Potential waterWorks:

snow accumulation
    ↓
melting
    ↓
water

Do not duplicate vanilla behavior if already implemented adequately.

======================================================================
87. EVAPORATION
======================================================================

Current B42 fluid simulation has at least some evaporation-related behavior
(e.g. special handling visible in fluid update research).

waterWorks can generalize water evaporation if needed.

Factors:

open/closed
temperature
outdoor exposure

BUT:

do not add expensive per-container simulation.

Use coarse scheduled updates.

======================================================================
88. FREEZING
======================================================================

Potential future feature:

outdoor pipes/tanks freeze in sufficiently cold weather.

Effects:

reduced flow
pipe damage
pump problems.

Requires climate integration.

CLASSIFICATION:
EXPERIMENTAL/FUTURE.

Kentucky climate makes this potentially relevant.

======================================================================
89. PIPE DAMAGE
======================================================================

Potential:

- freeze damage;
- zombie/environment damage;
- construction damage;
- corrosion.

Leak state:

network loses water.

Do not simulate random pipe failures constantly.

Damage should be understandable.

======================================================================
90. LEAKS
======================================================================

Possible network state:

connection integrity < threshold
    ↓
leak
    ↓
storage drains

Visual puddle rendering may be limited.

Gameplay water loss is straightforward.

CLASSIFICATION:
HIGH for logical leakage.
Visual dynamic puddles: VERIFY.

======================================================================
91. VALVES
======================================================================

Add:

- shutoff valve;
- branch valve;
- check valve where useful.

This makes network control possible.

CLASSIFICATION:
HIGH.

======================================================================
92. MANIFOLDS
======================================================================

Useful for:

central tank
    ↓
multiple circuits

Examples:

HOUSE
GARDEN
ANIMALS

Player can isolate circuits.

======================================================================
93. OVERFLOW
======================================================================

Full tank receiving rain:

overflow.

Potential future:

overflow pipe
    ↓
second tank

This enables cascaded storage.

CLASSIFICATION:
HIGH.

======================================================================
94. TANK LINKING
======================================================================

Allow multiple tanks to form storage banks.

Do not physically transfer tiny amounts every tick.

Treat connected equalized tanks as a logical reservoir where appropriate.

This is a major performance improvement.

======================================================================
95. RESERVOIR ABSTRACTION
======================================================================

waterWorks.Network.Reservoir

Can aggregate:

Tank A
Tank B
Tank C

Network sees:

Total capacity
Total volume

Individual container state can be reconciled when needed.

Use only if it preserves vanilla FluidContainer correctness.

Prototype carefully.

======================================================================
96. WATER TRANSFER
======================================================================

Prefer vanilla B42 fluid transfer primitives.

Do not manually:

source.amount = source.amount - X
target.amount = target.amount + X

when FluidContainer transfer APIs can do it correctly.

This preserves:

mixtures
capacity
sync
fluid identity.

======================================================================
97. MULTIPLAYER
======================================================================

Server should be authoritative for:

- fluid transfer;
- tank volume;
- water quality;
- filter state;
- pump state;
- network state;
- valve state;
- contamination;
- treatment;
- rain collection where appropriate.

Clients:

- UI;
- animation;
- predicted presentation where safe.

Do not trust clients to report water creation.

======================================================================
98. NETWORK SYNC
======================================================================

Current fluid containers already synchronize.

Avoid creating a second high-frequency sync stream.

waterWorks metadata should synchronize only when meaningful state changes.

Examples:

quality category changed
filter replaced
valve toggled
pump state changed
network rebuilt

Not:

every simulation tick.

======================================================================
99. IMPORTANT PERFORMANCE FINDING
======================================================================

Independent B42 server optimization research has found that vanilla's
FluidContainer simulation can become non-trivial on large servers because
registered fluid containers are visited frequently for rain/evaporation
processing.

Therefore waterWorks must NOT multiply this cost carelessly.

Do not create thousands of constantly updating pseudo-containers.

======================================================================
100. waterWorks PERFORMANCE MODEL
======================================================================

Use event-driven / coarse simulation.

RAIN:

one climate state
    ↓
cached catchment networks
    ↓
affected collectors/reservoirs

PLUMBING:

network changes
    ↓
recompute graph

not:

recompute entire network every frame.

QUALITY:

update when:
- fluid added;
- fluid removed;
- treatment performed;
- contamination event;
- coarse aging interval.

FILTER:

update when water passes through.

======================================================================
101. NO GLOBAL CONTAINER SCANS
======================================================================

Never:

for every tick:
    scan every IsoObject
    find every water container.

Maintain registries.

Registry:

activeNetworks
rainCatchments
poweredPumps
treatmentUnits
qualityTrackedContainers

Remove entries on unload/removal.

======================================================================
102. CHUNK LIFECYCLE
======================================================================

Networks crossing unloaded chunks require careful handling.

Do not retain unsafe object references indefinitely.

Persist network identity/topology.

Rebind loaded entities when chunks load.

Prototype this before supporting huge networks.

======================================================================
103. OFFLINE / UNLOADED SIMULATION
======================================================================

Do not simulate every pipe while unloaded.

Persist:

lastSimulationTime.

When relevant network reloads:

calculate coarse elapsed effects:

rain collected
filter aging if flow occurred
stagnation
etc.

Do not replay millions of ticks.

======================================================================
104. DEBUGGING
======================================================================

waterWorks requires a debug overlay.

Selected container:

Adapter
Fluid type
Amount
Capacity
Mixture
Vanilla tainted
waterWorks quality
Temperature if tracked
Network
Input
Output

Selected network:

ID
Sources
Storage
Pressure
Pumps
Filters
Valves
Consumers
Flow state

======================================================================
105. NETWORK DEBUG VIEW
======================================================================

Render conceptual lines:

SOURCE -> PIPE -> FILTER -> PUMP -> FIXTURE

Color/state can indicate:

connected
closed
unpowered
blocked
contaminated

Do not require debug visuals for normal gameplay.

======================================================================
106. WATER QUALITY DEBUGGER
======================================================================

Developer display:

Biological:
Particulate:
Chemical:
Salinity:
Turbidity:
Treatment:
VanillaTainted:

This will be essential for cross-mod testing.

======================================================================
107. WATER METER
======================================================================

Potential gameplay/debug item:

Water Test Kit

Advanced:

Water Quality Meter

Can reveal increasingly detailed information.

======================================================================
108. FEATURE FEASIBILITY MATRIX
======================================================================

FEATURE                              STATUS

B42 FluidContainer adapter           VERY HIGH
Fluid transfer                       VERY HIGH
Portable fluid containers            VERY HIGH
World fluid containers               VERY HIGH
Vanilla water-object adapter         VERY HIGH
Tainted-water compatibility          VERY HIGH
Fluid mixtures                       VERY HIGH
Rain collectors                      VERY HIGH
Rain intensity collection            VERY HIGH
Collector lids                       HIGH / VERIFY
Generic container API                VERY HIGH
Vanilla trough adapter               VERY HIGH
Natural water adapter                HIGH
Municipal-water adapter              HIGH
Vanilla plumbing adapter             HIGH
Gutters                              HIGH / DEMONSTRATED
Roof catchment                       HIGH / DEMONSTRATED
Downspouts                           HIGH / DEMONSTRATED
First-flush diverters                HIGH
Leaf screens                         HIGH
Large tanks                          HIGH
Cisterns                             HIGH
Linked tank storage                  HIGH
Player pipe network                  HIGH
Valves                               HIGH
Manifolds                            HIGH
Gravity feed                         HIGH
Simplified pressure                  HIGH
Hand pumps                           HIGH
Electric pumps                       HIGH
Pressure tanks                       HIGH
Filters                              HIGH
Sediment filtration                  HIGH
Carbon filtration                    HIGH
Ceramic filtration                   HIGH
Sand filtration                      HIGH
Filter degradation                   HIGH
Filter clogging                      HIGH
Boiling integration                  HIGH
Chemical treatment                   HIGH
Distillation                         HIGH
UV-C treatment                       HIGH
Water quality model                  HIGH
Cross-contamination                  HIGH
Water testing                        HIGH
Stagnation                           HIGH
Container cleanliness                HIGH
Hoses                                HIGH
Irrigation provider API              HIGH
Animal water API                     HIGH
Vehicle water tank                   HIGH/EXPERIMENTAL
Water trailer                        HIGH/EXPERIMENTAL
Hot water                            HIGH/EXPERIMENTAL
Water heater                         HIGH/EXPERIMENTAL
Showers consuming network water      HIGH/VERIFY
Toilet refill/flush                  HIGH/VERIFY
Graywater                            FUTURE/HIGH
Wastewater                           FUTURE
Septic system                        FUTURE
Groundwater model                    EXPERIMENTAL
Player-built wells                   EXPERIMENTAL
Freezing pipes                       EXPERIMENTAL
Dynamic leaks                        HIGH
Visual water puddles                 EXPERIMENTAL
True hydraulic simulation            DO NOT DO
Full fluid dynamics                  DO NOT DO
Replacing B42 FluidContainer         DO NOT DO

======================================================================
109. TECHNICAL SPIKES REQUIRED
======================================================================

Before final architecture, implement isolated prototypes.

WW-SPIKE-01
Read/write inventory FluidContainer.

WW-SPIKE-02
Transfer between two FluidContainers.

WW-SPIKE-03
World FluidContainer.

WW-SPIKE-04
Rain catcher behavior.

WW-SPIKE-05
Custom rain factor.

WW-SPIKE-06
Generic world collector.

WW-SPIKE-07
Vanilla sink/external water adapter.

WW-SPIKE-08
Vanilla plumbing detection.

WW-SPIKE-09
Natural water source adapter.

WW-SPIKE-10
Vanilla trough adapter.

WW-SPIKE-11
Fluid mixture quality propagation.

WW-SPIKE-12
Custom persistent water-quality metadata.

WW-SPIKE-13
Server-authoritative fluid transfer.

WW-SPIKE-14
Custom filter component.

WW-SPIKE-15
Two-node pipe connection.

WW-SPIKE-16
Multi-node network.

WW-SPIKE-17
Gravity-fed sink.

WW-SPIKE-18
Powered pump.

WW-SPIKE-19
Roof catchment calculation.

WW-SPIKE-20
Gutter -> tank collection.

WW-SPIKE-21
Network save/load.

WW-SPIKE-22
Network chunk unload/reload.

WW-SPIKE-23
Dedicated-server synchronization.

Do not build production content until these assumptions are proven.

======================================================================
110. DEVELOPMENT ROADMAP
======================================================================

WW0 — VANILLA/API AUDIT

- inspect current B42 Lua;
- inspect fluid components;
- inspect vanilla collectors;
- inspect plumbing;
- inspect wells;
- inspect natural water;
- inspect troughs;
- inspect fluid sync;
- build capability matrix.

WW1 — CORE ADAPTERS

- FluidContainerAdapter;
- legacy water adapter;
- natural source adapter;
- container registry;
- API;
- diagnostics.

WW2 — WATER QUALITY

- quality metadata;
- vanilla taint compatibility;
- mixing;
- transfer propagation;
- persistence;
- test tools.

WW3 — RAIN COLLECTION

- normalize collectors;
- lids;
- roof catchment;
- gutters;
- downspouts;
- first flush;
- debris screens.

WW4 — STORAGE

- barrels;
- tanks;
- cisterns;
- linked storage;
- overflow.

WW5 — PLUMBING CORE

- nodes;
- edges;
- pipes;
- junctions;
- valves;
- fixture adapters;
- vanilla plumbing compatibility.

WW6 — PRESSURE / PUMPS

- gravity;
- hand pumps;
- electric pumps;
- pressure abstraction;
- powerWorks integration.

WW7 — FILTRATION

- sediment;
- cloth;
- sand;
- carbon;
- ceramic;
- cartridges;
- clogging;
- maintenance.

WW8 — TREATMENT

- boiling compatibility;
- chemical treatment;
- distillation;
- lightWorks UV-C.

WW9 — CONSUMERS

- sinks;
- showers;
- toilets;
- hose outlets;
- other fixtures.

WW10 — farmWorks API

- irrigation provider;
- flow;
- quality.

WW11 — animalWorks API

- trough adapter;
- water-source query;
- animal consumption interface.

WW12 — VEHICLE / MOBILE WATER

- tanks;
- trailers;
- portable pumps.

WW13 — ADVANCED

- hot water;
- heaters;
- graywater;
- freezing;
- leaks;
- advanced maintenance.

======================================================================
111. CROSS-WORKS OWNERSHIP
======================================================================

waterWorks OWNS:

water
fluid-container adapters
water collection
water storage
water quality
contamination
filtration
water treatment
plumbing
pressure
pumps
valves
water distribution
water-source APIs

powerWorks OWNS:

electricity required by pumps/heaters/treatment equipment.

lightWorks OWNS:

UV/UV-C emitter and UV dose.

waterWorks consumes lightWorks UV for water treatment.

farmWorks OWNS:

crop response to irrigation.

animalWorks OWNS:

animal thirst and drinking behavior.

waterWorks exposes trough/container/source APIs.

medWorks OWNS:

medical consequences/treatment where appropriate.

waterWorks exposes water-quality data.

======================================================================
112. IMPORTANT CONTENT OWNERSHIP RULE
======================================================================

waterWorks does NOT add animal behavior.

waterWorks does NOT need to add a competing animal trough.

Vanilla B42 already has trough infrastructure.

waterWorks should make vanilla troughs first-class water-network consumers.

animalWorks then makes animals use the framework intelligently.

======================================================================
113. VANILLA-FIRST RULE
======================================================================

Whenever vanilla already has:

FluidContainer
rain collection
water source
well
sink
fixture
trough
container

ADAPT IT.

Do not create:

waterWorksRainBarrel
waterWorksSink
waterWorksBottle

merely because custom objects are easier to control.

A vanilla sink should benefit from waterWorks.

A vanilla rain collector should benefit from waterWorks.

A vanilla trough should benefit from waterWorks.

A vanilla bottle should benefit from waterWorks.

This is what makes waterWorks a framework rather than a content pack.

======================================================================
114. USER EXPERIENCE TARGET
======================================================================

Vanilla player:

Build barrel.
Wait for rain.
Carry water.
Boil water.

waterWorks early game:

Place containers.
Collect rain.
Boil/filter manually.

waterWorks mid game:

Gutters
    ↓
Tank
    ↓
Filter
    ↓
Gravity-fed sink

waterWorks late game:

Roof catchment
    ↓
First flush
    ↓
Cistern
    ↓
Pump
    ↓
Sediment filter
    ↓
Carbon/ceramic treatment
    ↓
UV-C treatment
    ↓
Pressure tank
    ↓
Manifold
       ├── Kitchen
       ├── Shower
       ├── farmWorks
       └── animalWorks

That should feel like rebuilding actual infrastructure after civilization
collapses.

======================================================================
115. FINAL ARCHITECTURAL RULE
======================================================================

DO NOT MAKE A BETTER WATER BARREL MOD.

MAKE WATER A SYSTEM.

B42 already gives waterWorks the foundational FluidContainer abstraction.

waterWorks should connect:

THE SKY
    ↓
ROOF
    ↓
GUTTER
    ↓
STORAGE
    ↓
TREATMENT
    ↓
PUMP
    ↓
PIPE
    ↓
FIXTURE
    ↓
CONSUMER

while preserving compatibility with vanilla FluidContainer behavior.

======================================================================
116. CODEX NEXT ACTION
======================================================================

Before production implementation:

1. Audit waterWorks repository.
2. Audit installed current B42 files.
3. Locate FluidContainer implementation and Lua exposure.
4. Inventory FluidType definitions.
5. Inspect vanilla rain collectors.
6. Inspect rain simulation.
7. Inspect current plumbing implementation.
8. Inspect natural-water actions.
9. Inspect wells.
10. Inspect sinks/toilets/showers/baths.
11. Inspect IsoFeedingTrough.
12. Inspect FluidContainer MP synchronization.
13. Verify transfer APIs from Lua.
14. Verify ModData/component persistence strategy.
15. Execute WW-SPIKE-01 through WW-SPIKE-23.
16. Update feasibility classifications from runtime evidence.
17. Design smallest stable waterWorks core.
18. Only then begin broad content implementation.

Repository + installed B42 runtime override this research whenever they disagree.