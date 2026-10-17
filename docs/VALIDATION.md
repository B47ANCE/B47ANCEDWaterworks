# B47ANCE’d Waterworks validation

Current version: 0.34.1.

[VERIFIED, source] Canonical version, current metadata, code and docs match.
This PATCH iteration fixes optional Power integration without changing the Mod
ID, Workshop ID, item identities, Waterworks sandbox settings or save schemas.
Historical rename records remain at 0.34.0 and are classified in version inventory;
prior validation is preserved verbatim at validation/0.34.0-rename.md.

## Reproduction and root cause

The user reported three host integration failures: first_party_pumps,
powered_flow and treatment_devices. The 0.34.0 baseline reproduced 48 PASS /
3 FAIL with actual current Power source. Failures occurred at
first_party_pumps.lua:27, powered_flow.lua:29 and treatment_devices.lua:23; the
last reported "no B47ANCEDPower battery". These are deterministic offline Lua
failures, not PZ runtime log evidence. No game/server was launched and no console
log is claimed to describe this host-only reproduction.

[VERIFIED, source and offline] Stale fixtures directly wrote old powerWorks
battery keys. The current Power implementation reads B47ANCEDPower-owned data.
An injected powerWorks global also masked six production lookup sites that
could not discover the real current Power global. New fixtures use Power's
initializeEmbeddedBattery/readConsumerCharge/inspectEnergyRecovery APIs on
host objects, with no injected alias. Correcting fixtures before production
exposed five failures. Updating the six lookups in five modules passes all cases.

## Commands and results

Bundled executable: Codex primary-runtime dependencies/python/python.exe.
Development dependency: requirements-dev.txt (lupa Lua 5.1). Objects are stubs;
the runner's table.unpack fallback is test-only. Exact project-root commands:

```powershell
python scripts/check_versions.py
python scripts/run_lua_tests.py --power-root ../B47ANCEDPower
python scripts/validate.py
```

[TESTED, offline Windows] With Power: 51 tests PASS, 0 FAIL, 0 SKIPPED;
45 runtime-source Lua 5.1 syntax files PASS. Standalone: 45 tests PASS,
6 optional-Power tests SKIPPED, 0 FAIL. Existing debit, rollback, treatment,
heating and command replay assertions remain. Additional assertions cover modern
API precedence over stale legacy power, unknown/missing/late availability,
legacy fallback, client denial and exact non-mutation without Power.
Version/identity, internal import case, translations, Lua-only source layout,
Workshop paragraph agreement and protected history/artwork checks PASS.

[VERIFIED, source] Power stays read-only, clean at HEAD/upstream
40ff9ebfe247d56d7dd2e308e7b7eabfb61a7ce0 on fix/audit-remediation (0/0;
default main ahead 1/behind 0). Source version 0.17.0-dev.1 and exact API hash
are recorded in POWER_INTEGRATION.md. Tests do not prove other Power versions.
No new vanilla API or runtime dependency is added. The resolver is internal
compatibility logic, so no new gameplay sandbox setting is meaningful.

## Remaining gates

[RUNTIME GATE] SP/hosted/dedicated NOT TESTED. G7 BLOCKED / NOT TESTED;
stable-release G8 BLOCKED. Follow POWER_INTEGRATION.md runtime acceptance for
real packs, API load order, consumer registration, charge/debit/rollback,
synchronization, chunk streaming, save/load, late join and dedicated restart.
Client intent/server validation, server-owned shared state, replay handling and
Power-owned battery/recovery persistence remain unchanged. No live save migration
is implemented or claimed. GitHub onboarding now targets the explicitly selected public repository
B47ANCE/B47ANCEDWaterworks. The initial main bootstrap has no gameplay source;
feature/github-onboarding imports the current development source for PR review.
The prior local-only report is preserved at validation/0.34.1-local-power.md.
Remote commit identity and CI status are verified after pushing and recorded in
the PR/task, not inferred from local metadata.

Additional onboarding checks: `python scripts/check_repository.py --staged`,
tracked-file review and `git diff --cached --check`. CI repeats the public index
audit, portable source validation, standalone tests and Power integration against
the pinned Power commit above. Official actions are commit-pinned and token
permissions are contents:read; CI performs no deployment or publishing.

The validator still checks every required tracked artwork/evidence hash.
Historical dist/ and the upload receipt are declared local-only: their absence
in a clean clone is reported, not presented as checked archive integrity. Their
presence still requires original hashes. Canonical version remains 0.34.1.
No package, --release artifact pass, deploy, publish, game/server launch, merge,
stable tag, Steam restart or branch-protection configuration is part of this task.
