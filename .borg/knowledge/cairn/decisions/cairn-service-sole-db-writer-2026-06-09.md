---
id: cairn-service-sole-db-writer-2026-06-09
date: '2026-06-10'
project: cairn
domain: architecture
tags:
- architecture
- service-layer
- upsert
- durability
alternatives: []
applies_to: []
confidence: 0.95
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260610-1630-cairn
created_at: '2026-06-10 16:50:37.416372+00:00'
updated_at: '2026-06-10 16:50:37.416373+00:00'
---

# cairn-service-sole-db-writer-2026-06-09

## decision

service.py is the sole layer that writes to the DB. drain.py replays outbox entries via service.record_document, never by writing to the DB directly.

## context

Multiple callers (API, MCP, CLI, drain) all need to write knowledge records.

## reasoning

Keeps upsert semantics (ON CONFLICT DO UPDATE, captured_at guard, embedding computation) in one place. Any direct DB write from drain would bypass the captured_at guard and risk silent data regression.
