# Waterworks validation

Current version: 0.35.2.

[VERIFIED, source] Compatible icon-only PATCH from 0.35.1. The approved generated
cutout is copied exactly to 42/icon.png and retained as an authoring master with
its prompt. Mod ID, Workshop ID, gameplay, saves, sandbox settings and Power
contracts are unchanged. No new game API, shared state or setting is needed.

[TESTED, offline Windows / Pillow read-only inspection] Icon/master SHA-256:
fbc91c809076263f0e9a6e617426246e6730cd249a952b1eee58e41371fa30c5
RGBA PNG, 1254x1254, alpha 0..255; four fully transparent corners.
No text/background fill was added. Native icon display remains NOT TESTED.

Both preview.png and the mod thumbnail retain SHA-256
1ac1ce5b27c2718b6a8d2137e5d5b1708a27e56199bcb908e0d5e6888ec6f50e.
Previous icon bytes are preserved at assets/artwork/history/icon-through-0.35.1.png.
Immutable rename provenance stays unchanged; only explicitly replaced artwork
paths resolve to archived originals. The completed prior report is preserved at
validation/0.35.1-preparation.md. Old results are not current runtime proof.

## Validation commands

```powershell
python scripts/check_versions.py
python scripts/validate.py
python scripts/run_lua_tests.py --power-root ../B47ANCEDPower
python scripts/check_repository.py --staged
git diff --cached --check
python scripts/prepare_workshop.py --mp-testing --output-root <verified-local-Workshop/_steamcmd> --game-manifest <verified-Steam-appmanifest_108600.acf>
```

[TESTED, offline Windows] All 16 version mirrors match. Standalone: 48 PASS /
0 FAIL / six optional-Power skips; with Power: 54 PASS / 0 FAIL / 0 SKIPS.
All 48 runtime Lua sources compile as Lua 5.1. Current icon identity/RGBA header,
PNG structure/CRCs/dimensions, unchanged thumbnail hashes, retained artwork/history,
Lua-only layout, case/localization and overview binding are checked. Actual CI,
merged commit, package hashes and upload outcome are recorded in the task/PR and
per-commit local release manifest. Power pin remains
40ff9ebfe247d56d7dd2e308e7b7eabfb61a7ce0.

## Distribution and runtime gates

Explicit publish authorization permits a labelled MP testing upload after all
other gates pass. Successful upload alone cannot establish runtime correctness.
Native icon/thumbnail display, crafting, nested inventory synchronization, SP and
dedicated multiplayer remain NOT TESTED. G7 and stable-release G8 remain BLOCKED.
See WORKSHOP_PUBLISHING.md, SEDIMENT_FILTER.md and POWER_INTEGRATION.md. No local
deployment or game/server launch is authorized. Steam restart requires separate
confirmation after successful upload. Historical dist/ and receipts are retained;
missing clone archives are NOT PRESENT rather than integrity PASS.
