# B47ANCEDWaterworks GitHub onboarding

Public repository: https://github.com/B47ANCE/B47ANCEDWaterworks

The complete source import was merged through PR #1. Canonical VERSION, tests
and documentation are on main. Subsequent iterations use named feature/fix
branches and PR review before merging main.

Development uses feature/fix branches and PRs. CI runs offline tests only, with
read-only repository permissions and commit-pinned official actions. It does not
deploy, publish, connect to a server or prove SP/dedicated correctness. No branch
protection configuration is claimed; required checks must pass before any merge.

Source authority, IDs and version mirrors are declared in version-inventory.json.
Historical local packages/receipts, shared config links, caches, diagnostic logs
and credentials are excluded from Git. Missing declared local-only history is
reported as NOT PRESENT in a clean clone; existing local history is hash-checked.
Tracked artwork and historical evidence remain required and hash-checked.
Git preserves exact source/evidence bytes without line-ending conversion.

Before every public push, run `python scripts/check_repository.py --staged`,
review the full index/diff and run current validation. This scanner checks common
credential patterns and forbidden paths; it is not proof that all secret types
can be detected. Actual push SHA and CI status are reported in the PR/task.
