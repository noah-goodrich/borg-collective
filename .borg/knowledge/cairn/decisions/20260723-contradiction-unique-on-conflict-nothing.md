---
id: 20260723-contradiction-unique-on-conflict-nothing
date: '2026-07-24'
project: cairn
domain: architecture
tags:
- postgresql
- contradiction-review
- idempotency
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
created_at: '2026-07-24 05:15:46.523149+00:00'
updated_at: '2026-07-24 05:15:48.083615+00:00'
---

# 20260723-contradiction-unique-on-conflict-nothing

## decision

Use UNIQUE(belief_id, conflicting_id) + ON CONFLICT DO NOTHING on contradiction_review inserts

## context

Detection runs could find the same pair multiple times; needed to prevent duplicate entries without erroring

## reasoning

Makes contradiction detection idempotent — running detect_contradictions repeatedly is safe and won't bloat the queue or surface already-dismissed pairs. The dismissed terminal state relies on this constraint to stay effective
