# Changelog

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
