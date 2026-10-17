# Clean-Room Research Record

REFERENCE MOD: Water Expanded (identified by the FadedMods research handoff)

DOMAIN: waterWorks

QUESTION: Is a persistent graph a plausible model for connected Build 42 fluid infrastructure?

ENGINE CAPABILITY OBSERVED: The supplied research handoff reports a working mod
using server-authoritative connected infrastructure, which establishes general
feasibility but does not establish an engine API or implementation contract.

VERIFIED AGAINST VANILLA: partial. The official Project Zomboid Java API confirms
the GlobalModData backing system supports get-or-create, save, request, and
transmit operations through the Lua-exposed ModData bridge. Chunk attachment
event semantics still need an isolated Build 42 runtime test.

OUR DESIGN CONSEQUENCE: waterWorks now has an independently designed,
serializable graph foundation with stable identifiers, typed channels, bounded
degree, explicit work budgets, revision invalidation, and atomic topology
publication. It is deliberately separated from world-object references.

SOURCE CODE COPIED: NO

IMPLEMENTATION DERIVED FROM REFERENCE: NO

FOLLOW-UP: Independently verify loaded-object attachment and multiplayer command
boundaries against vanilla Build 42 before wiring object events. No Water
Expanded source was opened for this pass.
