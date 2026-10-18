# B47ANCE’d Waterworks Power integration

Current version: 0.35.2.

[VERIFIED, source] Current Power API: `B47ANCEDPower`, with `powerWorks` used only
when the current global is absent. Lookups are dynamic and do not force-load an
optional mod. No synthetic alias is installed. Current API precedence also holds
when it reports unknown, unpowered or quarantined state; stale legacy state must
not bypass that decision.

The same precedence applies in FirstPartyPumps, FirstPartyTreatment, PumpPower,
Flow and TreatmentDevices. First-party device profiles register through Power.
Each transactional operation holds its selected API locally through reserve,
commit and rollback; Waterworks owns fluid/quality/thermal effects, while Power
owns energy, battery state and recovery. Waterworks does not initialize, copy,
rename or migrate live Power battery records. Existing Waterworks item, provider,
network, sandbox and save identifiers remain unchanged. No new gameplay setting
or persistent schema; namespace dispatch is an internal compatibility rule.

## Confirmed causes and regression

The three original failures were stale host fixtures writing `powerWorks`
battery state into the current Power implementation. Current Power reads its
`B47ANCEDPower` record and could not see those charged batteries. The old tests
also assigned `powerWorks=power`, masking six production lookups that could not
find a real installation exposing only `B47ANCEDPower`.

Fixtures now call `initializeEmbeddedBattery` on disposable host objects and
read charge and recovery through `readConsumerCharge`/`inspectEnergyRecovery`.
These fixture helpers are never called by Waterworks gameplay. Six actual-source
cases run without setting the old global. With fixtures corrected but production
unchanged, five cases failed (consumer registration, flow, treatment and current
API precedence); all pass after changing the six lookup sites.

[TESTED, offline Windows, Lua 5.1] All 51 tests and 45 source syntax checks PASS.
Coverage includes canonical precedence, legacy-only unit fallback, absent and
later-available API, unknown current state with a stale legacy global, charged
pump state, exact energy debit, verified rollback, treatment, heating and command
replay, client-authority denial and unchanged fluid/quality/temperature/charge
when Power is missing. Legacy fallback is unit-stub evidence, not an old-Power runtime test.

## Dependency evidence

Power was inspected read-only on branch `fix/audit-remediation`, clean HEAD and
upstream `40ff9ebfe247d56d7dd2e308e7b7eabfb61a7ce0`, ahead/behind 0/0, one commit
ahead of default main and zero behind. Its source metadata reports 0.17.0-dev.1.
Power API SHA-256: 55c88159806c7d8e3664cbaaa319b5e9580794332a6fc3b770acc05d118e035f.
No Power source or metadata was changed. No new vanilla API is used, so installed
game semantics are not newly claimed by these host tests.

## Runtime acceptance

[RUNTIME GATE] In disposable SP and dedicated worlds using matching source,
verify Power loads before first-party consumer registration; install/remove and
recharge a real pack; inspect charged, depleted and quarantined devices; route a
measured transfer, treat water, heat a frozen target, interrupt/retry operations,
repeat a request, unload/reload chunks, rejoin, save and restart. Verify one energy
debit per successful operation, no debit on proven rollback, authoritative fluid/
quality/temperature synchronization and no duplicate provider/event registration.
Do not use real player saves for destructive tests. Legacy Power save migration
belongs to Power and is neither attempted nor claimed here.

SP/hosted/dedicated NOT TESTED. G7 BLOCKED / NOT TESTED; stable-release G8 BLOCKED.
No package, deploy, publish or game/server launch. The initial public source import is prepared on `feature/github-onboarding` in
B47ANCE/B47ANCEDWaterworks; actual remote SHA and CI status are recorded by the
GitHub PR/task. See ../GITHUB_ONBOARDING.md.

## 0.35.0 continuation

The sediment housing needs no electricity and changes no Power contracts. The
current offline suite has 54 passing cases with the same Power source pin; prior
51-case 0.34.1 results above remain historical evidence. Native SP/dedicated
Power validation remains NOT TESTED; see VALIDATION.md for current commands.
