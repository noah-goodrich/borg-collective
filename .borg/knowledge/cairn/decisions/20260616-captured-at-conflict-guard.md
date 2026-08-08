---
id: 20260616-captured-at-conflict-guard
date: '2026-06-16'
project: cairn
domain: architecture
tags:
- replay
- postgres
- upsert
- ordering
- zero-loss
- outbox
alternatives: []
applies_to: []
confidence: 0.9
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260616-0914-cairn
created_at: '2026-06-16 10:27:03.289122+00:00'
updated_at: '2026-06-16 10:27:03.289123+00:00'
---

# 20260616-captured-at-conflict-guard

## decision

Drain replay MUST use ON CONFLICT (id) DO UPDATE ... WHERE EXCLUDED.captured_at >= documents.captured_at

## context

Outbox entries from different enqueue times can be replayed out of order (e.g. after a crash mid-drain); without a guard, an older body silently overwrites a newer one

## reasoning

The WHERE clause on the upsert makes the update a no-op if the incoming entry is older than what's already in the DB. The golden oracle must assert the live row equals the highest-captured_at entry across done/ ∪ pending/ — this is the only way to prove zero-loss without silent regression.
