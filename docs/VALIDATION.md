# Waterworks validation

Current version: 0.35.0.

[VERIFIED, source] Additive MINOR feature: first-party craftable sediment housing,
replaceable cartridges, explicit batch filtering and server sandbox controls.
Prior 0.34.1 GitHub validation is preserved verbatim in
validation/0.34.1-github.md; its evidence does not become current runtime proof.

## Commands and evidence

From the project root, using Python with requirements-dev.txt (lupa 2.6):

```powershell
python scripts/check_versions.py
python scripts/run_lua_tests.py --power-root ../B47ANCEDPower
python scripts/validate.py
python scripts/check_repository.py --staged
git diff --cached --check
```

[TESTED, offline Windows] Actual Power source: 54 PASS / 0 FAIL / 0 SKIPPED;
48 runtime-source Lua 5.1 syntax files PASS. Standalone: 48 PASS / 0 FAIL /
6 optional-Power SKIPPED. Host objects are stubs, not native PZ objects. Existing
Power pin remains 40ff9ebfe247d56d7dd2e308e7b7eabfb61a7ce0, API 0.17.0-dev.1.
No Power repository modifications are included. CI repeats standalone and pinned-
Power tests on Ubuntu; its final result is reported with the feature PR.

New assertions cover exact owned nested media, rejected removal, actor/reach/floor,
client denial, hostile payloads, generation/replay, capacity and hazard preservation,
ordinary route blocking, private treatment permission, verified media compensation,
uncertain water quarantine, restart table fixtures and client menu/action intent.
The command helper now preserves valid false returns, including living isDead=false.
Version, item/recipe translations, import case, Lua-only layout, Workshop paragraphs,
protected historical bytes and reviewed overview bindings are checked separately.
Actual native crafting and inventory synchronization remain unverified.

Source evidence is tied to Steam build 25485521, full engine version UNKNOWN;
see api/sediment-25485521.json and SEDIMENT_FILTER.md. No custom Java/JAR dependency,
external-mod implementation copying or new remote access is introduced.

## Runtime and release gates

[RUNTIME GATE] SP, hosted and dedicated multiplayer NOT TESTED. G7 BLOCKED /
NOT TESTED; stable-release G8 BLOCKED. SEDIMENT_FILTER.md specifies native recipes,
two-client races, interruption, streaming/relocation, save/reload and join/restart
acceptance. No automated repair/reset exists for quarantined housing operations.
Existing power runtime gates in POWER_INTEGRATION.md also remain outstanding.

Public pushes require freshness, index/secret review and exact remote SHA checks.
The PR records commit and CI outcome; local version metadata proves neither.
Historical dist/ and upload receipts stay local-only: present bytes are checked;
missing clean-clone archives are NOT PRESENT, never an archive integrity PASS.
No package, release artifact check, deploy, publish, stable tag or game/server launch
is part of this iteration. CI is read-only and does not establish G7/G8.
