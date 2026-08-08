---
id: 20260616-capacity-warning-at-session-start
date: '2026-06-16'
project: borg-collective
domain: architecture
tags:
- adhd-guardrails
- hooks
- borg-link
- capacity-management
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260616-0347-orchestrator
created_at: '2026-06-16 10:27:02.418180+00:00'
updated_at: '2026-06-16 10:27:02.418181+00:00'
---

# 20260616-capacity-warning-at-session-start

## decision

Capacity warning injected at SessionStart hook by counting active+waiting projects against BORG_MAX_ACTIVE threshold

## context

adhd-guardrails skill had no mechanism to surface overload state; users could start new work threads without awareness of existing load

## reasoning

SessionStart is the earliest intervention point; counting at hook time gives current state before any session context is loaded. Threshold via env var keeps it configurable without skill edits
