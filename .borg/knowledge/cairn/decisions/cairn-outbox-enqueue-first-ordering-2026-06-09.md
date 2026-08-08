---
id: cairn-outbox-enqueue-first-ordering-2026-06-09
date: '2026-06-10'
project: cairn
domain: durability
tags:
- outbox
- durability
- zero-loss
- filesystem
alternatives: []
applies_to: []
confidence: 0.98
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260610-1630-cairn
created_at: '2026-06-10 16:50:37.415411+00:00'
updated_at: '2026-06-10 16:50:37.415412+00:00'
---

# cairn-outbox-enqueue-first-ordering-2026-06-09

## decision

Outbox entries are written to the filesystem BEFORE any cairn API call or FS body write. The entry is the first durable artifact.

## context

Designing a zero-loss write path for when cairn is DOWN during a session.

## reasoning

If the API call happens first and then the FS write fails, the write is lost with no recovery path. Enqueue-first means a crash between enqueue and the API call leaves a recoverable entry.
