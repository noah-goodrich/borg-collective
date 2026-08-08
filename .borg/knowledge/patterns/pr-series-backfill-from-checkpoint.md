---
id: pr-series-backfill-from-checkpoint
project: borg-collective
domain: infrastructure
tags:
- backlog
- pr-management
- session-workflow
- checkpoint
preconditions: []
steps:
- Read the checkpoint doc to enumerate all outstanding work items.
- 'Sort work items by dependency: land foundational file changes (e.g., untracked
  file cleanup) before PRs that depend on those files being on main.'
- 'For each item: create branch, make changes, open PR, merge — completing one before
  starting the next to avoid cross-PR conflicts.'
- After each merge, verify local main is in sync with origin/main before branching
  for the next PR.
- Handle any PR with mixed concerns (commits already on main + new commits) via cherry-pick
  rather than rebase.
- Archive the directive/plan that initiated the backlog work as the final PR in the
  series.
pitfalls:
- 'Merging PRs out of dependency order causes conflicts that require additional fix
  PRs (exactly what happened with PR #21 conflicting after PR #29 landed).'
- Accumulating direct commits on local main between sessions creates a hidden divergence
  that must be rescued before any new branch work.
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.439204+00:00'
updated_at: '2026-06-16 10:27:02.439205+00:00'
---

# pr-series-backfill-from-checkpoint

## description

Clear a multi-PR backlog from a session checkpoint by processing PRs in dependency order
