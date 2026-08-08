---
id: mechanism-layer-extraction-slice
project: borg-collective
domain: architecture
tags:
- refactoring
- mechanism-layer
- lib
- plugin
- bats
preconditions: []
steps:
- Identify the duplicated logic and all locations (grep for function name across repo)
- Create `lib/<verb>.sh` as POSIX-compatible — no zsh-isms, no bashisms beyond POSIX
  sh
- Replace each duplicate body with `source lib/<verb>.sh` (or `. lib/<verb>.sh` for
  strict POSIX)
- 'Update `skills/<skill>/SKILL.md` inline prose to a pointer: ''See lib/<verb>.sh'''
- Write bats tests against `lib/<verb>.sh` directly — both the predicate and any public
  entry points
- Run `shellcheck` on the new lib file and all modified callers
- Run `scripts/sync-plugin.sh` to push updated SKILL.md into plugin distribution
- Open PR referencing the directive/plan acceptance criteria; verify all criteria
  in PR description
pitfalls:
- 'POSIX compatibility: `lib/` files may be sourced by both zsh and bash; avoid arrays,
  `[[ ]]`, and process substitution'
- 'Source path assumption: callers must resolve `lib/` relative to a stable anchor
  (repo root or `BORG_ROOT`), not `$0`'
- 'Plugin distribution drift: forgetting to run sync-plugin.sh after SKILL.md changes
  will silently leave the plugin stale'
- 'Test coverage gap: bats tests must cover the lib function *and* the caller integration,
  not just one layer'
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.521377+00:00'
updated_at: '2026-06-11 22:41:19.521378+00:00'
---

# mechanism-layer-extraction-slice

## description

Extract a duplicated shell predicate/function into `lib/`, wire all callers to source it, validate with bats, and sync plugin distribution.
