---
id: obs-20260709-usage-zero-cost
session_date: '2026-07-09'
project: borg-collective
tool: claude-code
tags:
- claude
- /usage
- cost
- token-spend
- latency
category: performance
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260709-1659-borg-collective
superseded_by: null
created_at: '2026-07-09 17:01:17.387954+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260709-usage-zero-cost

## content

/usage invocations cost $0.00 — measured directly: total_cost_usd: 0, num_turns: 0, zero tokens, ~350ms latency. This was previously assumed, not verified.

## resolution

Zero-cost is confirmed but rows still pollute session-count metrics. Use BORG_NO_SPEND_RECORD=1 on the invocation to suppress ledger writes.
