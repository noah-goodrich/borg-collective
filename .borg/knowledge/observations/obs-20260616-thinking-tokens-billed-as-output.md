---
id: obs-20260616-thinking-tokens-billed-as-output
session_date: '2026-06-16'
project: borg-collective
tool: claude-code
tags:
- token-spend
- opus
- thinking
- pricing
- anthropic
category: domain_knowledge
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.529618+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260616-thinking-tokens-billed-as-output

## content

Anthropic bills extended thinking tokens at the output token rate, not the input rate. For Opus, output tokens are significantly more expensive than input tokens. Cost models that treat thinking tokens as input tokens will substantially underestimate session cost for thinking-heavy workloads.

## resolution

Corrected in cost model PR #13. When instrumenting token spend, ensure thinking token counts are added to output token totals for cost calculation.
