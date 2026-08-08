---
id: cairn-four-state-demotion-guard-2026-06-09
session_date: '2026-06-10'
project: cairn
tool: claude-code
tags:
- signal
- outbox
- demotion
- zero-loss
- invariant
category: domain_knowledge
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260610-1630-cairn
superseded_by: null
created_at: '2026-06-10 16:50:37.423124+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# cairn-four-state-demotion-guard-2026-06-09

## content

Self-healing demotion from DOWN to NOT_INSTALLED must be hard-blocked while the outbox queue is non-empty. A non-empty queue means there are un-drained writes; silently demoting to NOT_INSTALLED would cause all future reads of those entries to be skipped.

## resolution

The _signal.classify_state() function checks queue_nonempty() before allowing DOWN to NOT_INSTALLED demotion. queue_nonempty() uses name-only directory listing (never json.loads) to avoid parsing overhead on the hot path.
