---
id: obs-20260731-source-tool-attribution-via-service
session_date: '2026-08-01'
project: cairn
tool: claude-code
tags:
- source_tool
- attribution
- backfill
- record_batch
- provenance
category: domain_knowledge
files_involved: []
confidence: 0.8
source_model: null
source_session: null
superseded_by: null
created_at: '2026-08-01 03:01:20.291306+00:00'
updated_at: '2026-08-01 03:01:20.291307+00:00'
---

# obs-20260731-source-tool-attribution-via-service

## content

Routing writes through service.record_batch enables source_tool attribution (source_tool='cairn-backfill-commit') automatically. Bare db.insert_* calls bypass this attribution mechanism entirely. Source attribution is a service-layer concern, not a DB-layer concern.

## resolution

Architecture insight: any write path that needs provenance tracking must go through the service layer. This is now the established pattern for backfill-commit and should be the default assumption for any new write paths.
