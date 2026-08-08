---
id: rescue-and-reset-diverged-local-main
project: borg-collective
domain: git-workflow
tags:
- git
- recovery
- local-main-divergence
preconditions: []
steps:
- 'Identify the divergence: git log --oneline origin/main..main to list stray commits.'
- 'Create a rescue branch from current local main: git checkout -b rescue/stray-commits-YYYYMMDD.'
- 'Reset local main to origin/main: git checkout main && git reset --hard origin/main.'
- 'Verify local main now matches origin: git log --oneline -5.'
- From the rescue branch, open PRs or cherry-pick the salvaged commits onto proper
  feature branches.
pitfalls:
- Do not skip the rescue branch step — once you reset --hard, the commits are only
  reachable via reflog if you didn't save them.
- Check for untracked or staged changes before resetting; they survive a reset but
  can cause confusion.
- If the stray commits are already partially represented in origin (e.g., merged via
  a different PR), audit each commit before promoting to avoid duplicates.
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.477154+00:00'
updated_at: '2026-06-11 22:41:19.477155+00:00'
---

# rescue-and-reset-diverged-local-main

## description

Safely recover when local main has diverged from origin/main due to commits made directly on the local branch instead of feature branches.
