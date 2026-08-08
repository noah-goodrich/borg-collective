---
id: 20260723-derive-status-from-superseded-by
date: '2026-07-24'
project: cairn
domain: architecture
tags:
- codex
- belief-store
- data-model
- patterns
- observations
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: null
created_at: '2026-07-24 03:54:03.154739+00:00'
updated_at: '2026-07-24 03:55:23.802040+00:00'
---

# 20260723-derive-status-from-superseded-by

## decision

Derive `status` for patterns and observations from `superseded_by IS NOT NULL` rather than adding a dedicated status column

## context

The belief typed-VIEW needs a unified `status` column across all three atom types. Decisions already have a status column; patterns and observations do not.

## reasoning

Avoids a new migration just to add a status column to patterns/observations when the superseded_by FK already encodes the only status distinction needed (active vs superseded). Keeps the schema minimal and the view logic self-contained.
