---
id: 20260616-cairn-cli-routes-through-service
date: '2026-06-16'
project: cairn
domain: architecture
tags:
- cairn
- cli
- service
- embeddings
- data-consistency
alternatives: []
applies_to: []
confidence: 0.9
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260616-0914-cairn
created_at: '2026-06-16 10:27:02.540118+00:00'
updated_at: '2026-06-16 10:27:02.540119+00:00'
---

# 20260616-cairn-cli-routes-through-service

## decision

All write entrypoints in cairn CLI must route through service.py, not directly to the data layer.

## context

cli.py record_* functions were bypassing service.py and writing directly, which skipped embedding generation and made CLI-recorded knowledge unsearchable.

## reasoning

Embeddings are generated in service.py. Any write path that bypasses service.py produces records that exist in the DB but cannot be found via similarity search — a silent data corruption class.
