---
id: dotfiles-push-with-unstaged-unrelated-changes
project: borg-collective
domain: infrastructure
tags:
- git
- dotfiles
- stash
- rebase
- workflow
preconditions: []
steps:
- git stash to park unstaged/uncommitted changes unrelated to the current work
- git pull --rebase to integrate remote commits (avoids a merge commit on a personal
  dotfiles repo)
- git stash pop to restore the parked changes
- Verify no conflicts; commit and push the intended changes
- Leave the stash-popped changes uncommitted if they are intentionally deferred (note
  this explicitly in the session debrief)
pitfalls:
- Forgetting to pop the stash leaves working changes invisible — always confirm 'git
  stash list' is empty or intentional before ending the session
- If the stash pop conflicts with rebased content, resolution must happen before push;
  do not force-push to resolve
- Deferred uncommitted changes (e.g. .zshrc) must be explicitly tracked in next-steps
  or they will be forgotten across sessions
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 20:39:24.979147+00:00'
updated_at: '2026-06-11 20:39:24.979147+00:00'
---

# dotfiles-push-with-unstaged-unrelated-changes

## description

Safely push dotfiles changes when unrelated unstaged edits exist in the working tree and the remote is ahead
