---
id: cairn-write-stderr-capture
project: borg-collective
domain: infrastructure
tags:
- cairn
- debugging
- stderr
- shell-scripting
preconditions: []
steps:
- Identify any `cairn write ...` call that pipes or redirects output away (e.g., `2>/dev/null`
  or unredirected in a subshell)
- 'Replace with a pattern that captures stderr: `output=$(cairn write ... 2>&1)` or
  tee to a log'
- On non-zero exit, emit the captured stderr to the operator (via `borg_osa_notify`
  or `echo >&2`)
- Update the failure nudge to reference a valid diagnostic subcommand (`cairn health`,
  not `cairn status`)
pitfalls:
- Discarded stderr is a silent failure — the hook appears to succeed while the knowledge
  write never happened
- Verify the subcommand name in the nudge message actually exists in the installed
  cairn version before shipping
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.521720+00:00'
updated_at: '2026-06-11 22:41:19.521721+00:00'
---

# cairn-write-stderr-capture

## description

Capture cairn write stderr in shell hooks so failures surface instead of being silently discarded.
