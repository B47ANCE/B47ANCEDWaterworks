# Project version policy

Root `VERSION` is the sole canonical project SemVer. `version-inventory.json`
declares current mirrors, authoritative source, Mod ID, display name and existing
Workshop identity. Check with `python scripts/check_versions.py` before and after
an iteration. Mismatched current mirrors block release.

This legacy project's canonical baseline was established from matching README,
mod.info, API, info.txt, roadmap and Workshop metadata at 0.33.1 with explicit
user approval. The approved identity iteration established 0.34.0; its records remain historical. Before 1.0,
activation/API-breaking development changes increment MINOR; compatible fixes
increment PATCH. Stable major-version contracts require a separate release policy
review. Game build, dependencies, schema and historical artifact versions remain
separate. Do not rewrite historical evidence or relabel old runtime tests.

`Contents/mods/B47ANCEDWaterworks/` is the authoritative runtime tree; there is no
parallel src tree. `dist/`, SHA256SUMS.txt and the previous uploader receipt are
historical outputs, not mirrors of current development source. No current release
artifact has been built. `--release` deliberately fails closed until packaging,
provenance and runtime release gates are established and satisfied.

Meaningful gameplay changes require dedicated G7 PASS before stable-release G8.
SP/offline results never substitute for that evidence. Explicit Workshop MP-test
uploads remain subject to the current shared exception and all other checks.
This policy does not authorize packaging, deployment, publishing or Git setup.
