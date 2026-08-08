---
id: atomic-state-write-on-hook-entry
project: borg-collective
domain: shell-scripting
tags:
- bash
- state-management
- hooks
- atomicity
preconditions: []
steps:
- Collect all state values to be written into local variables at the top of the hook.
- Call _borg_state_write once with all key=value pairs as a single JSON object merge.
- Avoid interleaving state writes with slow operations (git calls, network) that could
  be interrupted.
pitfalls:
- Writing state fields one at a time means a SIGINT between writes leaves state.json
  in a partial/inconsistent state that is hard to detect.
- Reading state immediately after a write in the same hook is safe, but reading from
  a different process concurrently may see a partial write if the write is not truly
  atomic (use a tmp-file + mv pattern for true atomicity if needed).
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.493642+00:00'
updated_at: '2026-06-11 22:41:19.493642+00:00'
---

# atomic-state-write-on-hook-entry

## description

When a hook needs to update multiple state fields, write all fields in a single atomic _borg_state_write call rather than multiple sequential writes. This prevents partial-state reads if a hook is interrupted mid-execution.
