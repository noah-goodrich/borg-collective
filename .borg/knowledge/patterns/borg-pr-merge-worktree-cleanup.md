---
id: borg-pr-merge-worktree-cleanup
project: borg-collective
domain: code-quality
tags:
- git
- worktree
- nanoprobe
- merge
- cleanup
preconditions: []
steps:
- 'Merge feature branch to main with --no-ff to preserve merge commit: `git merge
  --no-ff <branch>`'
- 'Push main to origin: `git push origin main`'
- 'Remove the worktree: `git worktree remove /tmp/<project>-<feature>-worktree`'
- 'Delete local feature branch: `git branch -d <branch>`'
- 'Verify remote branch is also cleaned up if nanoprobe pushed it: `git push origin
  --delete <branch>` (if applicable)'
pitfalls:
- Forgetting to remove the worktree leaves stale /tmp directories that can confuse
  future nanoprobes targeting the same path
- --no-ff must be specified explicitly; git may fast-forward by default on a clean
  history, losing the merge commit that marks the integration point
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.388319+00:00'
updated_at: '2026-06-16 10:27:02.388320+00:00'
---

# borg-pr-merge-worktree-cleanup

## description

Standard cleanup sequence after merging a nanoprobe feature branch via --no-ff merge commit
