---
id: 20260611-capacity-warning-at-session-start
date: '2026-06-11'
project: borg-collective
domain: infrastructure
tags:
- hooks
- adhd-guardrails
- capacity-management
- borg-link
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 22:41:19.460146+00:00'
updated_at: '2026-06-11 22:41:19.460146+00:00'
---

# 20260611-capacity-warning-at-session-start

## decision

Inject capacity warning at SessionStart hook rather than at plan-review or mid-session

## context

Need to surface overcommitment risk before new work threads are opened, not after

## reasoning

SessionStart is the earliest intervention point; surfacing the warning before any conversation begins gives the guardrails skill a chance to block new work intake proactively
