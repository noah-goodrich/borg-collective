---
id: 20260723-phase-1b-gated-on-corpus
date: '2026-07-24'
project: cairn
domain: architecture
tags:
- phase-1b
- staleness
- data-requirements
- project-planning
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: null
created_at: '2026-07-24 05:15:46.524380+00:00'
updated_at: '2026-07-24 05:15:48.083615+00:00'
---

# 20260723-phase-1b-gated-on-corpus

## decision

Phase 1b (learned per-scope staleness clock) is explicitly GATED until the corpus has sufficient real supersession events

## context

Phase 1b requires learning from real supersession patterns; at Phase 1a ship time, superseded_by is near-100% NULL

## reasoning

Building a learning system on an empty training set produces meaningless models. Gating forces the corpus to accumulate real data before investing in the learning machinery
