---
id: obs-20260616-opus-spend-is-96pct-main-loop
session_date: '2026-06-16'
project: borg-collective
tool: claude-code
tags:
- token-spend
- opus
- cost
- subagents
- cache-reads
- thinking
category: performance
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.528411+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260616-opus-spend-is-96pct-main-loop

## content

In a heavy claude-code session, ~96% of cost is in the Opus main loop (thinking-as-output tokens + cache reads at ~80M tokens/session) and only ~4% is subagents (Sonnet/Haiku). Earlier estimates of '$56/$43 Opus waves' were mispriced — thinking is billed as output, not input, and cache read vs. write pricing was conflated.

## resolution

Corrected cost model in #13. Spend optimization directive #46 reframed to target main-loop reduction (lean context, fewer turns, delegate output-heavy work with summary returns) rather than subagent tier-routing.
