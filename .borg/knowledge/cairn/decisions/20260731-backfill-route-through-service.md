---
id: 20260731-backfill-route-through-service
date: '2026-08-01'
project: cairn
domain: architecture
tags:
- backfill
- write-path
- service-layer
- embedding
- belief-integration
alternatives: []
applies_to: []
confidence: 0.9
status: active
superseded_by: null
cost_to_produce: null
source_tool: cairn-backfill-commit
source_model: null
source_session: null
created_at: '2026-08-01 03:01:20.090848+00:00'
updated_at: '2026-08-01 03:01:20.090851+00:00'
---

# 20260731-backfill-route-through-service

## decision

cairn backfill-commit routes mined candidates through service.record_batch instead of bare db.insert_*

## context

Issue #46 required deciding whether the backfill-commit mining write path should bypass or use the service layer. Three open design questions needed resolution.

## reasoning

Routing through service.record_batch gives mined rows embedding, call-logging, belief/contradiction visibility, and source_tool attribution for free. The old bare insert required a separate manual re-embed post-step that is now deleted. The service layer is the canonical write path and bypassing it created a second-class citizen for mined knowledge.
