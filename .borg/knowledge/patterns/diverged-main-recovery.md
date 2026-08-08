---
id: diverged-main-recovery
project: borg-collective
domain: infrastructure
tags:
- git
- dotfiles
- branch-recovery
- dead-branches
preconditions: []
steps:
- Identify that local main is tracking a dead remote branch (merged PR branch, not
  origin/main)
- Stash or note any uncommitted WIP
- Run `git fetch --prune` to update remote refs
- Run `git reset --hard origin/main` to realign local main
- Delete the dead local tracking branch if it persists
- Re-apply WIP as a new commit on the now-correct main
pitfalls:
- '`git reset --hard` discards uncommitted changes — always stash or record WIP first'
- 'The divergence is silent: `git status` may show ''ahead N'' without indicating
  the base is wrong; check `git log --oneline origin/main..HEAD` AND `git log --oneline
  HEAD..origin/main` to confirm the topology'
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.554660+00:00'
updated_at: '2026-06-16 10:27:02.554660+00:00'
---

# diverged-main-recovery

## description

Recover a local main branch that has diverged onto a merged-and-deleted remote PR branch, without losing WIP.
