---
id: 20260715-token-spend-dedup-session-peak
date: '2026-07-15'
project: cairn
domain: analytics
tags:
- token-spend
- deduplication
- sessions
- cost-tracking
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: null
created_at: '2026-07-15 15:41:50.297294+00:00'
updated_at: '2026-07-15 15:41:50.297294+00:00'
---

# 20260715-token-spend-dedup-session-peak

## decision

Deduplicate token_spend by taking the per-session peak snapshot rather than summing all snapshots

## context

The /stats/usage total was reporting $62,778.89 but the correct figure after dedup is $46,091.79 — a $16k overcount caused by multiple snapshot rows per session being summed

## reasoning

Token spend snapshots are cumulative within a session; summing them double- (or triple-) counts spend. The peak snapshot per session represents the true session cost.
