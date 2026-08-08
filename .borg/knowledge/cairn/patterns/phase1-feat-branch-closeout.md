---
id: phase1-feat-branch-closeout
project: cairn
domain: release-management
tags:
- git
- branching
- release
- borg-state
- handoff
preconditions: []
steps:
- Commit all feature work to the feat branch (e.g. feat/cairn-mcp-phase1-YYYY-MM-DD)
- Create a separate chore/borg-state-YYYY-MM-DD branch for session housekeeping
- Write a checkpoint .borg/checkpoints/YYYY-MM-DD-HHMM.md documenting what was done,
  blockers, and next-session steps
- Write a ready-to-assimilate handoff doc for any PROJECT_PLAN.md items that are now
  answered
- Write a merge-and-tag handoff doc with explicit PR title, squash-merge instructions,
  and tag command
- Explicitly list files NOT included in the borg-state PR (feat-branch uncommitted
  changes, untracked files) to avoid confusion
- 'Next session: resolve any open questions (e.g. accidental deletions), open PR,
  squash-merge, tag, move PROJECT_PLAN to assimilated/'
pitfalls:
- Uncommitted changes on the feat branch (e.g. .borg-project deletion, .gitignore
  edits) are invisible to the borg-state PR reviewer — must be explicitly called out
  in the checkpoint
- Placeholder checkpoints from orchestrators must be superseded and deleted in the
  same borg-state PR to avoid stale state
- The release tag should not be cut until the feat branch is merged to main — tagging
  from the feat branch creates an orphaned tag if the branch is squash-merged
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1925-cairn
superseded_by: null
created_at: '2026-06-11 23:12:50.717684+00:00'
updated_at: '2026-06-11 23:12:50.717685+00:00'
---

# phase1-feat-branch-closeout

## description

Pattern for closing out a multi-commit feature phase: separate borg-state branch from feat branch, document open questions, prepare merge+tag handoff docs before the next session does the actual merge.
