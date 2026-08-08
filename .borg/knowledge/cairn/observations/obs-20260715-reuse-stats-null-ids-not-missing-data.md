---
id: obs-20260715-reuse-stats-null-ids-not-missing-data
session_date: '2026-07-15'
project: cairn
tool: claude-code
tags:
- reuse-stats
- null-guard
- analytics
- debugging
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: null
superseded_by: null
created_at: '2026-07-15 15:41:50.301423+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260715-reuse-stats-null-ids-not-missing-data

## content

The reuse rollup (cairn reuse-stats / GET /stats/reuse) appeared to show ~97% zero-hit searches, which looked like missing data. Root cause was a null-guard bug in top_ids handling — the ids were never actually absent, the query was emitting null ids that broke aggregation downstream.

## resolution

PR #34: added null-guard on top_ids before aggregation. After the fix, the 'missing' data was revealed to be zero-hit searches (correct and expected), not a data gap.
