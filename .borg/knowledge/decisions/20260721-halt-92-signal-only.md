---
id: 20260721-halt-92-signal-only
date: '2026-07-21'
project: borg-collective
domain: architecture
tags:
- usage-guardian
- 92-percent
- veto
- separation-of-concerns
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: null
created_at: '2026-07-21 22:16:47.845521+00:00'
updated_at: '2026-07-21 22:16:47.845522+00:00'
---

# 20260721-halt-92-signal-only

## decision

The >=92% hard-stop is signal-only in this phase: the sweep writes the signal to guardian state but the actual PreToolUse veto hook is a separate deliverable, explicitly out of scope for PR #88

## context

The veto hook requires a different integration point (Claude hooks system) and different risk profile from the sweep mechanism

## reasoning

Separating concerns keeps PR #88 reviewable and independently mergeable. The sweep correctly persists the signal so the future veto hook has the data it needs without re-reading usage.
