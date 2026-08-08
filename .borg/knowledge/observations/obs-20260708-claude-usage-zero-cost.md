---
id: obs-20260708-claude-usage-zero-cost
session_date: '2026-07-09'
project: borg-collective
tool: claude-code
tags:
- claude-code
- usage
- cost
- api
- subprocess
category: tool_behavior
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260709-0431-orchestrator
superseded_by: null
created_at: '2026-07-09 15:25:36.246611+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260708-claude-usage-zero-cost

## content

`claude -p '/usage'` is non-interactive, requires no PTY, and costs exactly zero tokens (total_cost_usd: 0, num_turns: 0). It reads from the server-authoritative /api/oauth/usage endpoint. The response schema includes: five_hour, seven_day, utilization, resets_at, rate_limit_tier.

## resolution

Use `claude -p '/usage'` as a free polling mechanism for session and weekly burn rates. No token budget considerations needed.
