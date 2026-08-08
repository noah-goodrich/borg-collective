---
id: git-soft-reset-unstage-recommit
project: borg-collective
domain: git-hygiene
tags:
- git
- workflow
- clean-commits
preconditions: []
steps:
- Identify the accidentally-included file after committing (git show HEAD or git diff
  HEAD~1)
- git reset --soft HEAD^ to undo the commit while preserving all changes as staged
- git restore --staged <accidentally-included-file> to unstage only that file
- git commit with the same message to recommit cleanly without the unwanted file
- Verify the file is back to untracked with git status
pitfalls:
- git reset --hard would discard all working-tree changes — always use --soft when
  you want to keep the diff
- If the file was previously tracked (not untracked), git restore --staged won't return
  it to untracked state — use git rm --cached instead
- If the commit has already been pushed, a force-push is required — this pattern is
  safest before pushing
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 20:39:25.146967+00:00'
updated_at: '2026-06-11 20:39:25.146968+00:00'
---

# git-soft-reset-unstage-recommit

## description

Recover a commit that accidentally included an untracked file that should remain untracked
