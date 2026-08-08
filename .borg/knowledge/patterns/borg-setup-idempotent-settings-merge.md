---
id: borg-setup-idempotent-settings-merge
project: borg-collective
domain: dotfiles
tags:
- borg
- dotfiles
- idempotency
- permissions
- claude
- cortex
preconditions: []
steps:
- Substitute __DOTFILES_DIR__ placeholder in base JSON via sed before passing to jq
- 'Use jq to merge: combine base and live arrays with unique to deduplicate'
- Write to tmp file, abort cleanly on jq error (rm tmp, return 1)
- mv tmp over live settings file
- On first run, generate machine-local overlay template if it does not exist
pitfalls:
- If DOTFILES_DIR is unset or wrong, sed substitution silently produces invalid paths
  in the merged output — validate the var before running
- jq unique sorts the array; if downstream tooling is sensitive to permissions.allow
  ordering, this may cause spurious diffs
- The local overlay template is only generated on first run — if a user deletes it,
  borg setup will regenerate a blank template and their customizations are lost unless
  backed up
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 20:39:25.006916+00:00'
updated_at: '2026-06-11 20:39:25.006916+00:00'
---

# borg-setup-idempotent-settings-merge

## description

Pattern for union-merging a versioned dotfiles permissions base into a live settings file during borg setup, safe to re-run
