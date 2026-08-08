---
id: recover-bad-commit-wrong-branch
project: borg-collective
domain: git-workflow
tags:
- git
- worktree
- branch-mismatch
- stash
- recovery
preconditions: []
steps:
- Identify the branch mismatch (git branch / git log --oneline -3)
- Undo the bad commit with git reset HEAD~1 (keeps changes staged/unstaged)
- 'Stash the working changes with a descriptive name: git stash push -m ''<slug>-temp-stash'''
- Switch to the correct branch (or check out the correct worktree)
- 'Pop the stash on the correct branch: git stash pop stash@{N}'
- Re-commit with correct message and branch context
- Document the stash by name in a handoff doc so future sessions know it is intentional
pitfalls:
- git stash pop uses numeric index which shifts as other stashes are added/removed
  — always reference by name when documenting for handoff
- In a multi-worktree setup, stashes are global; a stash created in one worktree is
  visible and poppable from another, which can cause accidental application to the
  wrong working tree
- If the bad commit was already pushed, the branch needs a force-push after reset
  — verify remote state before assuming it is safe
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.408391+00:00'
updated_at: '2026-06-16 10:27:02.408392+00:00'
---

# recover-bad-commit-wrong-branch

## description

Recover cleanly when work has been committed or staged on the wrong branch in a worktree environment
