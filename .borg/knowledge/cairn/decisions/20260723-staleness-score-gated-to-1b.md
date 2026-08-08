---
id: 20260723-staleness-score-gated-to-1b
date: '2026-07-24'
project: cairn
domain: architecture
tags:
- codex
- belief-store
- phase-gating
- staleness
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: null
created_at: '2026-07-24 03:54:03.155256+00:00'
updated_at: '2026-07-24 03:55:23.802040+00:00'
---

# 20260723-staleness-score-gated-to-1b

## decision

Exclude staleness_score from the Phase 1a belief VIEW; gate it to Phase 1b

## context

The belief VIEW will expose age_seconds via EXTRACT(EPOCH FROM (now()-updated_at)). A computed staleness_score (normalized decay function) was considered for the same view.

## reasoning

staleness_score requires a defined decay model and calibration against real data. Shipping raw age_seconds in 1a gives consumers the primitive they need without locking in a scoring formula before it can be validated.
