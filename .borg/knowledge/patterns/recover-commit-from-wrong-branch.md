---
id: recover-commit-from-wrong-branch
project: borg-collective
domain: git-workflow
tags:
- git
- branch
- worktree
- recovery
- stash
preconditions: []
steps:
- 'Identify the mismatch: confirm which branch HEAD is on vs. which branch the work
  belongs to'
- Undo the bad commit with `git reset HEAD~1` (keep changes in working tree)
- 'Stash the changes with a descriptive name: `git stash push -m <descriptive-name>`'
- Switch to or check out the correct branch
- 'Pop the stash: `git stash pop` (or `git stash apply stash^{/<name>}` if non-trivial
  ordering)'
- Recommit on the correct branch
pitfalls:
- In a multi-worktree repo, `git stash list` is shared across worktrees — use named
  stashes to avoid popping the wrong one
- Verify the stash is still present on the original worktree after switching; it will
  be visible globally but the working directory context is gone
- If the bad commit was already pushed, a force-push to the wrong branch is required
  — coordinate with collaborators before doing so
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.453216+00:00'
updated_at: '2026-06-11 22:41:19.453216+00:00'
---

# recover-commit-from-wrong-branch

## description

Recover when a commit or work-in-progress lands on the wrong branch in a multi-worktree setup
