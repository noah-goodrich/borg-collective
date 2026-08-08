---
id: settings-json-floor-merge
project: borg-collective
domain: infrastructure
tags:
- jq
- settings-management
- dotfiles
- idempotency
- zsh
preconditions: []
steps:
- Locate base settings file (e.g., dotfiles/claude/settings.base.json)
- Substitute __DOTFILES_DIR__ placeholder with actual dotfiles path
- Write substituted content to a tmp file
- If machine-local settings file does not exist, copy base as-is and exit
- 'Use jq to union-merge: .permissions.allow = ((.permissions.allow // []) + (base.permissions.allow
  // [])) | unique'
- Write merged output to a second tmp file
- Atomically replace local settings file with merged tmp (mv)
- Clean up tmp files in all exit paths (including jq failure)
pitfalls:
- Any jq invocation in the function must have an error guard that removes tmp files
  on failure (|| { rm -f "$tmp"; return 1; }). Missing this guard causes stale tmp
  files on jq errors.
- __DOTFILES_DIR__ substitution must happen before jq sees the file, not inside the
  jq expression
- The merge must use unique to prevent duplicate entries accumulating across repeated
  borg setup runs
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.231620+00:00'
updated_at: '2026-06-11 22:41:19.231621+00:00'
---

# settings-json-floor-merge

## description

Union-merge a versioned base settings file into a machine-local settings file, keeping local entries and adding any missing entries from the base. Applied to both Claude and Cortex settings in borg setup.
