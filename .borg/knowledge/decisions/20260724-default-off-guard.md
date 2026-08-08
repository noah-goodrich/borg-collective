---
id: 20260724-default-off-guard
date: '2026-07-24'
project: borg-collective
domain: architecture
tags:
- usage-guardian
- feature-flags
- safety
- hooks
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: null
created_at: '2026-07-24 05:14:36.292276+00:00'
updated_at: '2026-07-24 05:14:37.809065+00:00'
---

# 20260724-default-off-guard

## decision

Both guardian halves (sweep at 85%, dispatch block at 92%) ship default-OFF behind environment variable flags (BORG_USAGE_SWEEP_ENABLED, BORG_USAGE_HALT_ENABLED).

## context

The thresholds are based on limited data (one near-cap episode for 85%). Shipping armed would risk false positives before the system is validated.

## reasoning

Allows the code to ship and be observed in production without behavioral impact. Live-cap validation requires a genuine near-cap session; the feature shouldn't be armed until that pass confirms end-to-end behavior. Threshold tuning requires 3+ near-cap episodes.
