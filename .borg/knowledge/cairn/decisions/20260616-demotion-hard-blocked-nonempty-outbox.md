---
id: 20260616-demotion-hard-blocked-nonempty-outbox
date: '2026-06-16'
project: cairn
domain: architecture
tags:
- cairn
- signal
- zero-loss
- state-machine
- outbox
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260616-0914-cairn
created_at: '2026-06-16 10:27:03.263904+00:00'
updated_at: '2026-06-16 10:27:03.263904+00:00'
---

# 20260616-demotion-hard-blocked-nonempty-outbox

## decision

State demotion (live→warming→not_installed) is HARD-BLOCKED while the outbox queue is non-empty

## context

Designing the four-state install signal classifier with zero-loss invariant

## reasoning

Allowing demotion while the outbox has pending entries would cause those entries to be abandoned, violating the zero-loss guarantee. The outbox must be drained before cairn can be considered degraded or uninstalled.
