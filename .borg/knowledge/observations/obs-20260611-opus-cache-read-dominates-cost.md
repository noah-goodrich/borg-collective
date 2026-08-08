---
id: obs-20260611-opus-cache-read-dominates-cost
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- token-spend
- cost
- claude-opus
- cache
- thinking
category: performance
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.540457+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-opus-cache-read-dominates-cost

## content

In heavy orchestrator sessions, ~96% of cost comes from the main loop (Opus thinking-as-output tokens + ~80M cache reads), not subagents. Earlier per-session estimates of '$56/$43 Opus waves' were mispriced due to incorrect cost model for cache read tokens. After correction, the real cost profile shifted the optimization target entirely to main-loop reduction.

## resolution

Corrected cost model in PR #13. Reframed spend-opt directive #46 to focus on orchestrator context leanness rather than subagent routing.
