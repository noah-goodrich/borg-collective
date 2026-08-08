---
id: local-main-divergence-rescue
project: borg-collective
domain: git-workflow
tags:
- git
- recovery
- main-branch
- feature-branch
preconditions: []
steps:
- 'Confirm the divergence: git log --oneline origin/main..HEAD to see the stray commits'
- 'Create a rescue branch at current HEAD: git checkout -b feat/rescue-branch-name'
- 'Switch back to main: git checkout main'
- 'Hard reset main to origin: git reset --hard origin/main'
- 'Verify main is clean: git log --oneline -5 and git status'
- Continue work on the rescue branch — open PR from there
pitfalls:
- If you have unstaged changes on main when you discover the problem, stash them first
  or they will survive the hard reset
- Confirm the rescue branch was created BEFORE doing the hard reset — double-check
  with git branch
- If commits were already pushed to a shared remote main, this approach needs coordination
  — a force-push to main would be required and is destructive
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.428592+00:00'
updated_at: '2026-06-16 10:27:02.428593+00:00'
---

# local-main-divergence-rescue

## description

Rescues commits accidentally made to local main by branching at current HEAD then resetting main to origin
