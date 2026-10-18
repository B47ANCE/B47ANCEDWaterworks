# Waterworks validation

Current version: 0.35.1.

[VERIFIED, source] Compatible artwork-only PATCH from 0.35.0. The submitted PNG
is copied byte-for-byte to preview.png and the authoritative mod thumbnail. Both
are 1254x1254 with SHA-256
1ac1ce5b27c2718b6a8d2137e5d5b1708a27e56199bcb908e0d5e6888ec6f50e.
The existing 32x32 icon and gameplay are unchanged. No new API, synchronization,
save schema or sandbox setting is needed for this local presentation delta.

The former artwork is preserved byte-for-byte at
assets/artwork/history/thumbnail-through-0.35.0.png. Immutable rename provenance
is unchanged; the validator resolves only its two replaced artwork paths to that
archive and still verifies their original hashes. Current artwork is checked
independently against artwork-provenance.json, including PNG structure/chunk CRCs.
Prior 0.35.0 validation is preserved at validation/0.35.0-sediment.md, not relabelled
as current runtime proof. The reviewed overview version/digest is refreshed.

## Commands and offline evidence

From the project root with Python and requirements-dev.txt:

```powershell
python scripts/check_versions.py
python scripts/validate.py
python scripts/run_lua_tests.py --power-root ../B47ANCEDPower
python scripts/check_repository.py --staged
git diff --cached --check
```

[TESTED, offline Windows] Version consistency, exact current artwork identity,
PNG structure/CRC/dimensions, prior artwork/history, Lua-only layout, translation
and import case checks PASS. Standalone Lua 5.1: 48 PASS / 0 FAIL / 6 optional-
Power skips; with Power: 54 PASS / 0 FAIL / 0 SKIPS. All 48 runtime Lua files
compile. Power pin remains 40ff9ebfe247d56d7dd2e308e7b7eabfb61a7ce0.
CI repeats source audits and standalone/pinned-Power tests on Ubuntu. The task/PR
records actual commit, remote SHA and CI outcome after pushing.

## Remaining gates

[RUNTIME GATE] Native thumbnail display/scaling and actual Workshop upload are
NOT TESTED. The supplied image is retained at its original dimensions and file
size, with no claim of uploader acceptance. Existing crafting, SP and dedicated
multiplayer gates remain NOT TESTED; G7 and stable-release G8 remain BLOCKED.
See SEDIMENT_FILTER.md and POWER_INTEGRATION.md for gameplay acceptance. No
packaging, release tag, live deployment, game/server launch or Steam upload is
part of this iteration. Historical dist/ and upload receipts remain local-only;
missing clone artifacts are NOT PRESENT rather than an archive-integrity PASS.
