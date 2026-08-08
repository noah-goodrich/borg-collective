---
id: 20260708-reject-token-spend-jsonl-as-live-signal
date: '2026-07-09'
project: borg-collective
domain: architecture
tags:
- claude-code
- hooks
- token-tracking
- session-end
alternatives: []
applies_to: []
confidence: 0.9
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260709-0431-orchestrator
created_at: '2026-07-09 15:25:36.241838+00:00'
updated_at: '2026-07-09 15:25:36.241839+00:00'
---

# 20260708-reject-token-spend-jsonl-as-live-signal

## decision

Reject token-spend.jsonl as a live burn-rate signal

## context

Initial spike considered reading token-spend.jsonl to estimate session usage in real time.

## reasoning

token-spend.jsonl is written at SessionEnd hook firing. A running session contributes zero to the file. This is structurally blind — not merely imprecise — making it categorically unsuitable for mid-session monitoring.
