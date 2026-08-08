---
id: 20260709-best-effort-usage-logging
date: '2026-07-09'
project: cairn
domain: architecture
tags:
- usage-tracking
- observability
- error-handling
- reliability
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260709-1535-cairn
created_at: '2026-07-09 15:36:29.689187+00:00'
updated_at: '2026-07-09 15:36:29.689190+00:00'
---

# 20260709-best-effort-usage-logging

## decision

Wire usage logging as best-effort (never raises, never blocks) via a helper that wraps all call_log writes in try/except

## context

Adding a usage ledger to every search/briefing/record call risked turning a logging failure into a service failure

## reasoning

Observability instrumentation must not degrade the system it measures. A failed log write should never propagate to the caller. The call_log rows are analytics, not transactional data.
