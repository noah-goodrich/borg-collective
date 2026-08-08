---
id: cairn-v0.2-fail-hard-model-2026-06-10
date: '2026-06-10'
project: cairn
domain: reliability
tags:
- reliability
- zero-loss
- v0.2
- architecture
alternatives: []
applies_to: []
confidence: 0.95
status: active
superseded_by: null
cost_to_produce: null
source_tool: claude-code
source_model: null
source_session: 20260610-1613-cairn
created_at: '2026-06-10 16:27:17.602592+00:00'
updated_at: '2026-06-10 16:27:17.602595+00:00'
---

# cairn-v0.2-fail-hard-model-2026-06-10

## decision

cairn uses a four-state availability signal (NOT_INSTALLED/WARMING/LIVE/DOWN) with enqueue-first zero-loss writes via a durable filesystem outbox when DOWN; only NOT_INSTALLED is the silent path

## context

Old v0.1 model silently dropped writes on outage. New model: fail-hard when installed, enqueue-first when down, so no writes are ever lost.

## reasoning

Fail-hard surfaces outages immediately; enqueue-first means no writes are lost; the kill switch (remove install marker) and warm-up window prevent boot storms.
