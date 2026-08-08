---
id: obs-20260708-token-spend-jsonl-sessionend-only
session_date: '2026-07-09'
project: borg-collective
tool: claude-code
tags:
- claude-code
- hooks
- token-spend
- session-end
- analytics
category: tool_behavior
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260709-0431-orchestrator
superseded_by: null
created_at: '2026-07-09 15:25:36.249802+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260708-token-spend-jsonl-sessionend-only

## content

token-spend.jsonl is written exclusively by the SessionEnd hook. A running session contributes zero bytes to the file. Additionally, each `claude -p '/usage'` subprocess poll appends a $0 record to token-spend.jsonl via SessionEnd, and `--settings '{"hooks":{}}'` does NOT suppress this.

## resolution

Do not use token-spend.jsonl for live burn-rate monitoring. Filter `est_cost_usd > 0` in any token-cost analytics to exclude poll-subprocess noise, or add an env guard in the hook.
