---
id: 20260428-cairn-best-effort-session-record
date: '2026-06-11'
project: cairn
domain: infrastructure
tags:
- hooks
- session-recording
- reliability
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1925-cairn
created_at: '2026-06-11 20:31:17.996514+00:00'
updated_at: '2026-06-11 20:31:17.996515+00:00'
---

# 20260428-cairn-best-effort-session-record

## decision

Call `cairn record session` from borg-link-up.sh (Stop hook) as best-effort (no exit-code check) rather than failing the hook on API unavailability

## context

Session-end hook must not block or error the session teardown process if the cairn API is down

## reasoning

The value of auto-recording is cumulative over many sessions; missing one record is acceptable. Blocking session teardown on a non-critical observability tool is unacceptable.
