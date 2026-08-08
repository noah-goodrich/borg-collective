---
id: cairn-write-failure-diagnosis
project: borg-collective
domain: infrastructure
tags:
- cairn
- debugging
- observability
- hooks
preconditions: []
steps:
- Check whether the hook script is discarding stderr (`2>/dev/null` or unredirected
  in a subshell)
- 'Temporarily add stderr capture: `cairn write ... 2>/tmp/cairn-debug.log` and inspect
  the log'
- Verify the subcommand name — `cairn health` not `cairn status`
- Check that the cairn binary is on PATH in the hook execution environment (hooks
  may have stripped PATH)
- Once root cause found, make stderr capture permanent (log or surface it) rather
  than reverting
pitfalls:
- '`cairn status` does not exist — the correct health-check subcommand is `cairn health`;
  using the wrong one in a failure nudge sends developers on a dead-end'
- Hook environments frequently have different PATH than interactive shells; a tool
  that works interactively may silently fail in a hook
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.504174+00:00'
updated_at: '2026-06-16 10:27:02.504175+00:00'
---

# cairn-write-failure-diagnosis

## description

Diagnose silent cairn write failures in hook contexts where stderr is discarded.
