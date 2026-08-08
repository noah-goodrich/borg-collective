---
id: obs-20260611-spend-opt-cairn-ac-ordering
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- directives
- spend-optimization
- cairn
- dependency-ordering
category: domain_knowledge
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.561986+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-spend-opt-cairn-ac-ordering

## content

The spend-opt directive's AC3 (cairn-warm brief wired into dispatch) is explicitly gated on the out-of-repo cairn knowledge backfill being complete. Attempting to implement AC3 before cairn is validated and backfilled would wire the brief to an empty or stale knowledge base, defeating its purpose.

## resolution

Enforce the gate: complete cairn validation + backfill (next session step 1) before implementing AC3. AC4 (token-spend.jsonl measurement artifact) has no such gate and can proceed independently.
