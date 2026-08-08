---
id: jq-additive-union-merge-json-array
project: borg-collective
domain: infrastructure
tags:
- jq
- settings-management
- idempotency
- permissions
- dotfiles
preconditions: []
steps:
- Resolve any placeholders in the base file via sed before passing to jq (e.g. sed
  's|__DOTFILES_DIR__|'"$DOTFILES_DIR"'|g' base.json)
- Use jq --slurpfile or process substitution to load both the live file and the resolved
  base
- 'Compute the merged array: ($live.permissions.allow + $base.permissions.allow) |
  unique'
- 'Write the result back using jq''s update operator: .permissions.allow = <merged_array>'
- Write output to a temp file then mv into place atomically to avoid partial-write
  corruption
pitfalls:
- If placeholder substitution via sed is skipped, the literal placeholder string ends
  up in the merged JSON and may cause the consuming tool to reject the settings file
- Using | unique alone does not guarantee stable ordering; if the consuming tool diffs
  settings files, ordering churn can appear as noise. Consider | unique | sort if
  stability matters.
- The guard if [[ ! -f ]] for overlay template generation means first-run defaults
  are only seeded once. If defaults change in a future borg version, existing machines
  will not receive the update automatically — document this limitation.
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.224744+00:00'
updated_at: '2026-06-11 22:41:19.224745+00:00'
---

# jq-additive-union-merge-json-array

## description

Idempotently union-merge a versioned array (e.g. permissions.allow) from a base JSON file into a live JSON file using a single jq invocation, without touching other fields in the live file.
