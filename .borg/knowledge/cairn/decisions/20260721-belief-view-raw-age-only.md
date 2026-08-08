---
id: 20260721-belief-view-raw-age-only
date: '2026-07-21'
project: cairn
domain: architecture
tags:
- codex
- belief-store
- sql-view
- phase-planning
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: null
created_at: '2026-07-21 22:17:44.748200+00:00'
updated_at: '2026-07-21 22:17:44.748203+00:00'
---

# 20260721-belief-view-raw-age-only

## decision

The belief VIEW exposes raw `age_seconds` only in Phase 1a — no computed staleness_score

## context

During Collective review of the Codex ADR, the question arose whether to include a derived staleness_score in the belief VIEW from day one.

## reasoning

Keeping 1a to raw age_seconds avoids baking in a staleness scoring formula before we have empirical data on what thresholds are meaningful. Derived/learned staleness is deferred to 1b, keeping 1a verifiable and reversible.
