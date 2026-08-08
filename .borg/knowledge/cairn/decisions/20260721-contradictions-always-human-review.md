---
id: 20260721-contradictions-always-human-review
date: '2026-07-21'
project: cairn
domain: architecture
tags:
- codex
- contradiction-detection
- human-in-the-loop
- belief-store
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: null
created_at: '2026-07-21 22:17:44.751989+00:00'
updated_at: '2026-07-21 22:17:44.751990+00:00'
---

# 20260721-contradictions-always-human-review

## decision

Contradictions between beliefs always route to human review — no automated resolution in any phase

## context

ADR 0001 locked this as a non-negotiable anchor during the Collective review.

## reasoning

Automated contradiction resolution risks silently discarding valid beliefs. The cost of a false-positive auto-resolution (losing real knowledge) is higher than the cost of a human review queue item.
