---
id: obs-20260721-contradiction-candidate-snapshot-must-persist
session_date: '2026-07-21'
project: cairn
tool: claude-code
tags:
- codex
- belief-store
- contradiction-detection
- review-queue
category: domain_knowledge
files_involved: []
confidence: 0.7
source_model: null
source_session: null
superseded_by: null
created_at: '2026-07-24 03:53:11.050397+00:00'
updated_at: '2026-07-24 03:55:24.084484+00:00'
---

# obs-20260721-contradiction-candidate-snapshot-must-persist

## content

The contradiction review queue must persist the candidate snapshot at detection time: the conflicting row id, similarity score at detection, and triggering feedback signal. Without this, a re-review after the source data changes has no record of what triggered the flag — the contradiction may no longer be detectable from current data.

## resolution

PR-B spec includes persisting these fields on the review queue write endpoint. Treat the snapshot as an immutable event record, not a live join to current state.
