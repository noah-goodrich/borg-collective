---
id: obs-20260616-spend-opt-ac3-cairn-gate
session_date: '2026-06-16'
project: borg-collective
tool: claude-code
tags:
- directives
- spend-optimization
- cairn
- ac-gating
- backfill
category: domain_knowledge
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.556329+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260616-spend-opt-ac3-cairn-gate

## content

spend-opt AC3 (cairn-warm brief wired into dispatch) is explicitly gated on the out-of-repo cairn knowledge backfill being complete. Attempting AC3 before the backfill produces a warm brief sourced from an empty or stale knowledge graph, making the feature untestable and potentially shipping with misleading warm-context behavior.

## resolution

Track AC3 as blocked; do not begin implementation until cairn backfill is confirmed complete (validated by record counts matching pre-migration baseline: ~86 sessions / 8 decisions / 5 patterns / 8 observations / 1 document).
