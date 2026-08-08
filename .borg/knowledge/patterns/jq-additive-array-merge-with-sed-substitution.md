---
id: jq-additive-array-merge-with-sed-substitution
project: borg-collective
domain: infrastructure
tags:
- jq
- json
- dotfiles
- bash
- idempotency
- settings-management
preconditions: []
steps:
- Read the base file from dotfiles; run `sed 's|__DOTFILES_DIR__|'"$DOTFILES_DIR"'|g'`
  to substitute path placeholders before passing to jq
- 'Use jq to merge: `jq -s ''.[0].permissions.allow = (.[0].permissions.allow + .[1].permissions.allow
  | unique) | .[0]'' live.json <(sed ...) > $tmp`'
- 'On jq failure, clean up tmp immediately: `|| { rm -f "$tmp"; return 1; }`'
- On success, `mv "$tmp" live.json` for atomic replacement
- 'Verify idempotency: running setup twice should not change the output file'
pitfalls:
- Forgetting `|| { rm -f "$tmp"; return 1; }` leaves orphaned tmp files and may cause
  the function to return success on jq failure
- If the live settings file does not yet exist, jq's `.[0]` will be null — guard with
  a file-existence check or initialize from base on first run
- sed placeholder substitution must happen before jq sees the JSON; piping substituted
  output via process substitution (`<(...)`) avoids a temp file for the base
- '`unique` sorts the array as a side effect — if order of permissions.allow matters
  downstream, this will silently reorder entries'
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.239644+00:00'
updated_at: '2026-06-11 22:41:19.239644+00:00'
---

# jq-additive-array-merge-with-sed-substitution

## description

Safely union-merge a versioned JSON settings base into a live settings file: substitute path placeholders via sed, merge arrays with jq unique, write to tmp, then atomic-replace — with cleanup on failure.
