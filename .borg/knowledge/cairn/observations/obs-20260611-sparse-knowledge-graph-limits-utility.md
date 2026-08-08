---
id: obs-20260611-sparse-knowledge-graph-limits-utility
session_date: '2026-06-11'
project: cairn
tool: cursor
tags:
- cairn
- knowledge-graph
- backfill
- search
- utility
category: domain_knowledge
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260611-1925-cairn
superseded_by: null
created_at: '2026-06-11 23:12:50.734846+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-sparse-knowledge-graph-limits-utility

## content

With only 1 decision and 4 sessions in the cairn knowledge graph at end of v0.2, cairn search returns too few results to be useful in SessionStart prompts. The system is architecturally sound but practically empty. The threshold for useful cross-session retrieval is estimated at 20+ records.

## resolution

Prioritize backfilling historical knowledge from borg session exports (`cairn backfill <path>` + `cairn backfill-commit`) before relying on cairn search in production workflows. Do not evaluate cairn search quality until the graph has 20+ records.
