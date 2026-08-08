---
id: multi-repo-coordinated-commit-push
project: cairn
domain: infrastructure
tags:
- git
- multi-repo
- dotfiles
- borg-collective
- coordination
preconditions: []
steps:
- Complete all changes in all repos before committing any, to verify the full picture
  is consistent
- Push dependency repos first (borg-collective, dotfiles) since they have no pending
  PR gates
- Leave the repo with an open PR branch (cairn fix/backfill-extraction-robustness)
  committed but unpushed until PR workflow is ready next session
- Verify each repo's working tree is clean after push before declaring session done
- Record exact commit SHAs in session notes so next session can reference them without
  re-running git log
pitfalls:
- Rebasing borg-collective on remote (8513c97 → 93a9e59) can reorder commits; verify
  the accrual block lines up correctly after rebase
- cairn branch commits accumulate across sessions (e70ff3b, 95ad27b, 2fe1346) — track
  the full range for the PR description, not just the latest
- launchd plist must be loaded explicitly after dotfiles push; pushing dotfiles does
  not auto-register the agent
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260618-0029-cairn
superseded_by: null
created_at: '2026-06-18 00:30:17.385580+00:00'
updated_at: '2026-06-18 00:30:17.385581+00:00'
---

# multi-repo-coordinated-commit-push

## description

Coordinating commits and pushes across three related repos (cairn, borg-collective, dotfiles) that have interdependent changes from a single work session
