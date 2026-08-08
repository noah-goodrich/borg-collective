---
id: merge-worktree-cleanup
project: borg-collective
domain: code-quality
tags:
- git
- worktree
- merge
- cleanup
- nanoprobe
preconditions: []
steps:
- 'Merge with --no-ff to preserve merge commit in history: `git merge --no-ff <branch>`'
- 'Push merged main to origin: `git push origin main`'
- 'Remove the worktree: `git worktree remove /tmp/<project>-<branch>-worktree`'
- 'Delete the local feature branch: `git branch -d <branch>`'
- Confirm remote branch deletion if applicable (or leave for PR close to handle)
pitfalls:
- Forgetting to remove the worktree leaves stale /tmp entries that can confuse subsequent
  nanoprobes targeting the same path
- --no-ff is important for auditability; without it the merge looks like a fast-forward
  and the feature boundary is lost
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.437656+00:00'
updated_at: '2026-06-11 22:41:19.437656+00:00'
---

# merge-worktree-cleanup

## description

Standard cleanup sequence after a nanoprobe merges a feature branch via worktree
