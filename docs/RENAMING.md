# B47ANCE’d Waterworks identity and compatibility

Current version: 0.34.0.

The display name is B47ANCE’d Waterworks and the only active Mod ID is
`B47ANCEDWaterworks`. The project/package folder uses `B47ANCEDWaterworks`.
The existing Workshop item stays `3788594390`; no item or visibility change.
This is a pre-1.0 MINOR iteration from 0.33.1 because enabled-mod identity changes.

## Activation and existing saves

Back up a save before testing. Replace `waterWorks` with `B47ANCEDWaterworks` in
its enabled-mod selection and in dedicated-server Mods lists. Keep the existing
Workshop item in WorkshopItems. Update dependent mods’ `require=` declarations
when they explicitly require the old Mod ID. Do not enable both copies together.
There is no second legacy Mod ID package: that would risk duplicate runtime hooks.
No save file or server configuration is modified by this rename.

Retained compatibility contracts are intentional:

- `waterWorks/*` Lua imports and the `waterWorks` global/API table.
- All `waterWorks.*` item/recipe identifiers and item tags.
- `SandboxVars.waterWorks` and the existing sandbox option/translation keys.
- Network module/command identifiers, stable provider/node IDs and operation IDs.
- All persisted quality, recovery, placed-object and GlobalModData keys/schemas.

`require "B47ANCEDWaterworks/API"` and the `B47ANCEDWaterworks` global expose
that same API table. Both import orders are covered offline, including an API
already run by the engine/legacy loader. The alias does not create another
registry, treatment definition, event registration, transaction or authoritative
state. Branding adds no gameplay settings; labels and identity are not balance
configuration. Existing server sandbox configuration remains authoritative.

Source paths retain `media/lua/*/waterWorks/` because they are public integration
paths, independent of Mod ID. Item script contents retain module `waterWorks`,
while their filename is now `B47ANCEDWaterworks_Items.txt`.

## Evidence and distribution

The previous 0.33.1 source was backed up before edits. Existing `dist/` outputs,
SHA256SUMS.txt, upload receipt and historical research records remain immutable
historical evidence; their former name/version is not a current identity mirror.
Artwork remains exact original bytes. See rename provenance and VALIDATION.md.
No package, deploy, upload, game/server launch or Steam restart is part of this
change. GitHub setup/push is BLOCKED pending the user-selected repository; this
local iteration is NOT BACKED UP TO GITHUB. A verified local backup exists.

Native saved-item retention, mod activation, save/load, reconnect and dedicated
restart are NOT TESTED. Shared state stays server-owned; existing synchronization,
validation, persistence and replay handling are unchanged. G7 BLOCKED / NOT TESTED;
stable-release G8 BLOCKED. Older clients must use matching source/Mod ID when
testing; no mixed-version multiplayer compatibility is claimed.
