---
id: idempotent-managed-block-injection
project: borg-collective
domain: configuration-management
tags:
- borg
- dotfiles
- merge
- idempotent
- zsh
preconditions: []
steps:
- 'Define delimiters: <!-- BEGIN borg-managed --> and <!-- END borg-managed -->'
- 'In _borg_merge_claude_md(): read the target file, strip everything from BEGIN delimiter
  to END delimiter (inclusive) plus any trailing blank lines left by the removal'
- Append the current managed content from $BORG_HOME/config/... wrapped in the delimiters
- Write result back to target file
- 'Verify idempotency: running twice produces byte-identical output (strip + re-append
  of same content)'
pitfalls:
- Trailing blank lines after the stripped block must be explicitly cleaned up or diffs
  will accumulate on each run
- If the user manually edits content inside the delimiters, those edits will be silently
  overwritten on next borg setup run — document this clearly
- The delimiter style must not conflict with the target file format (HTML comments
  work for Markdown; use a different convention for JSON/YAML files)
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 20:39:25.061070+00:00'
updated_at: '2026-06-11 20:39:25.061070+00:00'
---

# idempotent-managed-block-injection

## description

Inject a managed section into a user-editable file using HTML-comment delimiters, stripping the old block before re-appending, so the operation is byte-identical across consecutive runs.
