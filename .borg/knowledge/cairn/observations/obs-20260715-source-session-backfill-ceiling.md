---
id: obs-20260715-source-session-backfill-ceiling
session_date: '2026-07-15'
project: cairn
tool: claude-code
tags:
- backfill
- source-session
- attribution
- data-quality
- limits
category: domain_knowledge
files_involved: []
confidence: 0.7
source_model: null
source_session: null
superseded_by: null
created_at: '2026-07-15 15:41:50.301909+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260715-source-session-backfill-ceiling

## content

Even with a complete backfill run, source_session attribution can only reach ~82% of records. The ceiling is structural: records created before session tracking was implemented have no session event to match against. The remaining ~18% cannot be attributed by heuristics alone.

## resolution

Accept the ceiling for automated backfill. The only path to recovering attribution for the remaining records is an LLM re-mining pass to infer session membership from content/timestamp proximity — deliberately deferred and noted in the PR.
