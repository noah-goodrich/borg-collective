---
id: 20260501-reveal-score-integer-vs-float
date: '2026-06-16'
project: borg-collective
domain: architecture
tags:
- reveal
- scoring
- supabase
- database-schema
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260616-0347-orchestrator
created_at: '2026-06-16 10:27:02.265147+00:00'
updated_at: '2026-06-16 10:27:02.265148+00:00'
---

# 20260501-reveal-score-integer-vs-float

## decision

Store rubric_score as NUMERIC(4,2) in triage_results alongside existing integer potential_score and archetype_fit_score

## context

The Python scoring.py computes rich float rubric scores (0-10) but only 0-5 integer summaries are persisted. This makes it impossible to distinguish top 10% from top 30% of photographs using DB queries alone.

## reasoning

Persisting the float rubric score enables server-side ranking and filtering without re-running the Python pipeline. Adding a new column is non-breaking and keeps the existing integer fields for backward compatibility.
