---
id: obs-20260611-knowledge-graph-too-sparse-for-useful-search
session_date: '2026-06-11'
project: cairn
tool: cursor
tags:
- cairn
- knowledge-graph
- search
- backfill
- cold-start
category: pattern_discovered
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260611-1925-cairn
superseded_by: null
created_at: '2026-06-11 20:31:18.026681+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-knowledge-graph-too-sparse-for-useful-search

## content

After completing v0.2 and the restoration directive, the cairn knowledge graph contained only 1 decision, 4 sessions, 0 patterns, 0 observations. At this density, cairn search returns results but they are not meaningfully useful for surfacing cross-session context during SessionStart prompts.

## resolution

Backfill historical knowledge from borg session exports using the cairn backfill pipeline (drone exec cairn -- cairn backfill <path>; cairn backfill-commit). Target 20+ records before expecting useful SessionStart context. This is the highest-value next action post-v0.2.
