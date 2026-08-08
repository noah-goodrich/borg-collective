---
id: obs-20260730-re-embed-step-was-workaround
session_date: '2026-07-30'
project: cairn
tool: claude-code
tags:
- backfill
- embedding
- technical-debt
- write-path
category: domain_knowledge
files_involved: []
confidence: 0.7
source_model: null
source_session: null
superseded_by: null
created_at: '2026-07-30 23:23:43.300862+00:00'
updated_at: '2026-07-30 23:23:43.300863+00:00'
---

# obs-20260730-re-embed-step-was-workaround

## content

The manual `re-embed` post-step in the backfill workflow existed solely to patch around the bare `db.insert_*` path not triggering embedding. Once writes were routed through `service.record_batch`, the re-embed step became redundant and was deleted.

## resolution

When you see a manual post-processing step that 'fixes up' data after a write, it's a signal the write is bypassing the service layer. Route through the service layer and delete the patch.
