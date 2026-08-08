---
id: 20260611-timeout-guard-cairn-hook
date: '2026-06-11'
project: borg-collective
domain: infrastructure
tags:
- hooks
- cairn
- shell
- reliability
- timeout
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 22:41:19.340156+00:00'
updated_at: '2026-06-11 22:41:19.340157+00:00'
---

# 20260611-timeout-guard-cairn-hook

## decision

Add `timeout 5` guard to `cairn record session` in borg-link-up.sh to match the existing timeout on `cairn search` in borg-link-down.sh

## context

During /simplify review, parity was missing between the two hooks — borg-link-down.sh already had a timeout on its cairn invocation but borg-link-up.sh did not, creating an asymmetric failure mode where a hung cairn process could block session startup indefinitely.

## reasoning

Session lifecycle hooks must not block the developer workflow. A 5-second ceiling caps blast radius of any cairn daemon failure. Parity between up/down hooks makes the pattern easier to reason about and audit.
