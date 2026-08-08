---
id: 20260319-lru-cache-engine
date: '2026-06-11'
project: cairn
domain: architecture
tags:
- sqlalchemy
- python
- testing
- database
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1925-cairn
created_at: '2026-06-11 20:31:17.982726+00:00'
updated_at: '2026-06-11 20:31:17.982727+00:00'
---

# 20260319-lru-cache-engine

## decision

Apply lru_cache to get_engine() for a single process-wide engine; tests bypass cache via Alembic's sqlalchemy.url config key with NullPool

## context

Need one engine in production but tests need to inject a different database URL without hitting the cached engine

## reasoning

lru_cache gives cheap singleton behavior; Alembic's config override mechanism provides a clean seam for test injection without monkey-patching
