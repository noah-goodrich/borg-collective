---
id: 20260730-backfill-route-through-service
date: '2026-07-30'
project: cairn
domain: architecture
tags:
- backfill
- write-path
- service-layer
- embedding
- call-log
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: cairn-backfill-commit
source_model: null
source_session: null
created_at: '2026-07-30 23:23:43.083632+00:00'
updated_at: '2026-07-30 23:23:43.083635+00:00'
---

# 20260730-backfill-route-through-service

## decision

Route `cairn backfill-commit` writes through `service.record_batch` instead of bare `db.insert_*` calls

## context

Issue #46 identified that mined candidates were being written directly to DB, bypassing embedding, call-logging, and contradiction visibility. Three design questions were open about how to fix this.

## reasoning

Using the service layer ensures mined rows are embedded on write, logged, and visible to belief/contradiction detection — the same guarantees as any other record path. It also eliminates the manual `re-embed` post-step that previously patched around the gap.
