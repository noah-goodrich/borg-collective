---
id: 20260721-status-derived-from-superseded-by
date: '2026-07-24'
project: cairn
domain: architecture
tags:
- codex
- belief-store
- sql
- views
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
created_at: '2026-07-24 03:53:11.043182+00:00'
updated_at: '2026-07-24 03:55:23.802040+00:00'
---

# 20260721-status-derived-from-superseded-by

## decision

For patterns and observations in the belief VIEW, derive `status` from `superseded_by IS NOT NULL` rather than adding a status column to those tables

## context

Decisions have an explicit status column; patterns and observations do not. The unified belief VIEW needs a consistent status field across all three atom types.

## reasoning

Avoids schema changes to patterns/observations tables (which would require additional migrations and ORM updates) while still conveying the meaningful state difference. The semantics are equivalent: a record with a superseded_by pointer IS superseded.
