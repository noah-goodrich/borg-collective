---
id: 20260616-async-deferred-consent-breakglass
date: '2026-06-16'
project: cairn
domain: architecture
tags:
- cairn
- zero-loss
- break-glass
- non-interactive
- outbox
alternatives: []
applies_to: []
confidence: 0.9
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260616-0914-cairn
created_at: '2026-06-16 10:27:03.264444+00:00'
updated_at: '2026-06-16 10:27:03.264445+00:00'
---

# 20260616-async-deferred-consent-breakglass

## decision

Break-glass prompt is deferred and async — not an interactive prompt in the hook — because hooks are non-interactive

## context

Adversarial review found that the original break-glass design required an interactive prompt, which is impossible in a non-interactive Stop hook

## reasoning

A Stop hook runs non-interactively; blocking on a user prompt would hang indefinitely or be killed. Deferring break-glass consent (e.g., via a pending file the user reviews later) closes this hole while preserving the zero-loss intent.
