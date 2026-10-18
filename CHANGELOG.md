# Changelog

## 0.35.1 - 2026-10-17

- Add an explicit prepare-only Workshop packaging helper and documented source,
  ZIP, staging and VDF integrity checks for the selected existing item. Preserve
  visibility, prior packages and original artwork; no login/upload/restart is run
  by the helper. Publication preparation keeps the same 0.35.1 build.
- Add verified public source URL, compatibility/configuration and known runtime
  limitations to canonical Workshop prose while preserving attribution/format.

- Replace the Workshop authoring preview and in-game thumbnail/poster with the
  user-supplied Waterworks artwork, preserving exact 1254x1254 PNG bytes.
- Preserve prior artwork under assets/artwork/history/ and keep its original
  rename-provenance hashes verified. Keep the existing icon and gameplay intact.
- Record current artwork hashes/dimensions and synchronize version mirrors and
  overview bindings. Prior 0.35.0 validation is retained as historical evidence.
- Offline validation only; native thumbnail presentation and dedicated gameplay
  remain NOT TESTED. No package, deployment or Workshop upload is included.

## 0.35.0 - 2026-10-17

- Add a craftable sediment filter housing and consumable sand/cloth cartridges.
  Timed install/replace and connected-container batch filtering submit intent to
  the server; no client owns inventory, water quality or remaining capacity.
- Defaults: 100 fluid units per cartridge and 75% particulate/turbidity removal
  per batch. Biology, chemicals and salinity remain unchanged. Add four sandbox
  controls for enablement, capacity, removal fraction and action presentation time.
- Persist housing identity, media generation, capacity, bounded replay history
  and interruption records. Verify media compensation only after proven unchanged
  water; uncertain outcomes remain quarantined without an automatic reset.
- Block ordinary routed flow through batch filters. Preserve existing item IDs,
  optional Power integration and all existing registry schemas.
- Offline: 54 cases pass with actual Power source; standalone 48 pass / 6 skip.
  Native crafting, SP and dedicated multiplayer NOT TESTED; G7/stable G8 BLOCKED.
- Adopt the reviewed feature/connection descriptor and document exact recipes,
  source fingerprints, English fallback and remaining runtime acceptance gates.

## 0.34.1 - 2026-10-16

- Fix powered pumps, treatment and heating to prefer the current B47ANCEDPower
  API while retaining legacy powerWorks support.
- Remove the artificial legacy global from six actual-Power integration fixtures.
  Initialize fixture batteries and inspect charge/recovery through public APIs.
- Cover current-name precedence, unknown/missing/late Power and legacy fallback.
- All 51 host Lua tests pass with actual Power source; native SP/dedicated
  behavior remains NOT TESTED. No Power source or saved battery keys changed.
- Public GitHub onboarding targets B47ANCE/B47ANCEDWaterworks with reviewed
  feature-branch source import and read-only offline CI.

## 0.34.0 — 2026-10-16

- Rename the product to B47ANCE’d Waterworks and Mod ID to `B47ANCEDWaterworks`.
- Rename package/project folders and item-script filename; update Workshop text,
  sandbox page display and localized inspector/sampling window titles.
- Preserve existing Lua imports, item types, settings, protocol and save keys;
  add a branded API alias sharing the existing state in both import orders.
- Establish approved canonical VERSION, version inventory/policy and offline
  validation runner. Keep existing Workshop ID, artwork and historical outputs.
- Activation requires replacing the former Mod ID in enabled-mod lists and any
  dependent metadata. See docs/RENAMING.md and docs/VALIDATION.md.
- Local iteration only; no Git repository/remote configured. GitHub push BLOCKED.
  SP and dedicated NOT TESTED; G7 and stable-release G8 BLOCKED.

## Earlier evidence

Original version-specific notes remain in WORKSHOP_CHANGE_NOTE.txt and the
existing architecture/testing/research records. Their evidence is historical.
