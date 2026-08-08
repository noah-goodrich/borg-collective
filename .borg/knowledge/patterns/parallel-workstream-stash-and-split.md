---
id: parallel-workstream-stash-and-split
project: borg-collective
domain: git-workflow
tags:
- git
- stash
- branching
- worktree
- parallel-streams
preconditions: []
steps:
- Identify which files belong to the primary PR (e.g., borg-state files only).
- Stash all other modified files with a descriptive stash name (e.g., `git stash push
  -m 'borg-state-2026-05-27-temp-stash'`).
- Commit and push the narrow PR from the clean worktree.
- Checkout a new branch for the parked changes (e.g., `chore/project-state-YYYY-MM-DD`).
- Pop the stash (`git stash pop`) onto the new branch.
- Commit and PR the parked changes separately.
pitfalls:
- Stash reference can be lost if the branch is deleted or the stash is popped prematurely
  — record the stash name and branch in a handoff doc immediately.
- If the stashed files include modifications to files also touched by the primary
  PR (e.g., CLAUDE.md), stash pop will produce conflicts.
- Forgetting to record which branch the stash lives on makes recovery painful; always
  note the branch name alongside the stash name.
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.398087+00:00'
updated_at: '2026-06-16 10:27:02.398087+00:00'
---

# parallel-workstream-stash-and-split

## description

When multiple unrelated workstreams accumulate uncommitted changes in a single worktree, use git stash to temporarily park cross-cutting changes, cut a narrow PR for the primary concern, then unstash onto a fresh branch for the parked changes.
