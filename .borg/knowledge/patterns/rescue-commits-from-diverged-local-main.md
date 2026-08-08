---
id: rescue-commits-from-diverged-local-main
project: borg-collective
domain: infrastructure
tags:
- git
- branch-management
- local-main-divergence
- recovery
preconditions: []
steps:
- 'Identify the divergence: `git log --oneline origin/main..main` to see commits on
  local main not on origin.'
- 'Create a rescue branch from the current (diverged) local main: `git checkout -b
  rescue/temp-branch-name`'
- 'Reset local main hard to origin/main: `git checkout main && git reset --hard origin/main`'
- From the rescue branch, cherry-pick or open a PR with the rescued commits.
- 'Verify local main now matches origin: `git log --oneline main origin/main | head
  -5`'
pitfalls:
- Do not `git pull --rebase` on a diverged local main without first rescuing the commits
  — rebase can produce confusing duplicate commits if the work partially overlaps
  with remote.
- If the rescue branch contains commits that already landed on main via another PR,
  cherry-pick selectively rather than opening the rescue branch as-is.
- Check for untracked/staged changes before the hard reset or they will be lost.
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.438809+00:00'
updated_at: '2026-06-16 10:27:02.438810+00:00'
---

# rescue-commits-from-diverged-local-main

## description

Recover work that was accidentally committed directly to local main when it has diverged from origin/main
