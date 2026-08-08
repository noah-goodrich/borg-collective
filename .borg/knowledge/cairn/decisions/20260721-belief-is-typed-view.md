---
id: 20260721-belief-is-typed-view
date: '2026-07-21'
project: cairn
domain: architecture
tags:
- codex
- belief-store
- sql-view
- data-model
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: null
created_at: '2026-07-21 22:17:44.751497+00:00'
updated_at: '2026-07-21 22:17:44.751498+00:00'
---

# 20260721-belief-is-typed-view

## decision

A 'belief' in Cairn is a typed SQL VIEW over existing tables, not a new first-class table

## context

ADR 0001 locked this anchor during adversarial Collective review.

## reasoning

Avoids denormalisation and dual-write complexity; beliefs are always derivable from source records, making them naturally consistent. A VIEW can be evolved without migrating stored belief rows.
