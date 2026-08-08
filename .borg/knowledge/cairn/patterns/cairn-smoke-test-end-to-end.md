---
id: cairn-smoke-test-end-to-end
project: cairn
domain: testing
tags:
- cairn
- smoke-test
- postgres
- drain
- breakglass
preconditions: []
steps:
- Verify cairn service is reachable (health check)
- Force DOWN state by simulating or triggering the DOWN classification path
- Enqueue a note record via the HTTP API
- Run drain to flush the queue to Postgres
- Query the cairn DB directly to confirm the row exists (cairn:note:cairn:smoke-test-v0.2
  pattern)
- Confirm breakglass flag is auto-cleared after successful drain
- Verify all 17 check points pass (queue depth, DB row count, state transitions)
pitfalls:
- Breakglass must auto-clear after drain — if it persists, drain did not complete
  cleanly
- Smoke test writes a real row to production DB; use a distinct key prefix (smoke-test-*)
  for easy identification and cleanup
- DOWN state classification must be verified independently of drain — the queue should
  hold records correctly before drain is invoked
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1925-cairn
superseded_by: null
created_at: '2026-06-11 20:31:18.025149+00:00'
updated_at: '2026-06-11 20:31:18.025150+00:00'
---

# cairn-smoke-test-end-to-end

## description

End-to-end smoke test verifying the full cairn v0.2 write path: DOWN classification → queue → drain → DB persistence → breakglass auto-clear.
