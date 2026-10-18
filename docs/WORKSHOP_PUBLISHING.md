# Workshop build preparation

Canonical inputs: VERSION, version-inventory.json, WORKSHOP_ID.txt,
WORKSHOP_DESCRIPTION.txt, WORKSHOP_CHANGE_NOTE.txt, workshop.txt, preview.png,
and Contents/mods/B47ANCEDWaterworks/. Existing item: 3788594390, App ID 108600.
Public source: https://github.com/B47ANCE/B47ANCEDWaterworks.

The user's current instruction is prepare-only. The initial cached SteamCMD
sign-in was rejected; no content upload was attempted. Authentication failure is
not validation evidence about the build, and no credentials/logs are committed.
Do not retry login or upload without renewed authorization.

## Preparation command

Run current freshness and source validation first. From clean committed source:

```powershell
python scripts/check_versions.py
python scripts/validate.py
python scripts/run_lua_tests.py --power-root ../B47ANCEDPower
python scripts/prepare_workshop.py --mp-testing --output-root <verified-local-Workshop/_steamcmd> --game-manifest <verified-Steam-appmanifest_108600.acf>
```

The helper creates a fresh per-commit folder and refuses existing destinations.
It preserves prior artifacts and never deletes/moves source or staging. ZIP files
are deterministic, with sorted members and fixed timestamps. The package contains
the native Contents/mods layout, authoring preview/metadata, canonical VERSION and
selected change note. SteamCMD's contentfolder points only to staged Contents;
source/docs, local configuration and tooling are not runtime payload. The one
tracked empty-directory shared/.keep marker (empty or one line break) is explicitly excluded and its
hash recorded in the manifest; all other hidden/unexpected runtime paths fail.

Preparation verifies clean source/upstream SHA and default-branch ancestry,
canonical versions/IDs, Lua-only runtime extensions, path/case safety, exact
source/stage hashes, ZIP member inventory, traversal/duplicate/case/CRC checks,
read-back hashes, and real paragraph breaks. A manifest binds the Git commit,
version, Mod ID, Workshop ID, source tree/package/VDF hashes, minimum Build 42
version, locally observed Steam build when supplied, and actual validation gates.
The helper repeats source validation; Power validation is a separate prerequisite.
The manifest reports only that prerequisite as requiring separate evidence, not
as an automatically inferred PASS. Both canonical texts carry the MP-testing
notice; source URL and known limitations remain explicit.

The UTF-8 BOM VDF follows the existing SteamCMD update workflow and existing item
ID. It omits visibility/tags to preserve remote settings. Its multiline description
and changenote preserve actual line breaks. It includes no credentials and never
invokes SteamCMD or the desktop client. The original user PNG remains unchanged;
uploader acceptance and native thumbnail rendering remain NOT TESTED.

## Distribution gates

This prepares an MP testing build under shared WORKSHOP_MP_TESTING.md policy.
It does not make the stable `check_versions.py --release` gate pass: gameplay G7
and stable-release G8 remain BLOCKED. Prior source/game evidence remains tied to
its own version/commit. Actual client download, server startup, two-client races,
join/rejoin, persistence and dedicated restart still require human runtime tests.
Use disposable saves; do not automatically resolve uncertain housing operations.

A later explicit publish instruction can authorize the reviewed VDF through the
verified SteamCMD executable and cached authentication. Recheck source freshness,
exact package/VDF hashes and CI, confirm upload success, then ask separately before
restarting Steam. A build-only request never authorizes authentication retries,
Workshop changes, a new item, visibility changes, local deployment or server work.
