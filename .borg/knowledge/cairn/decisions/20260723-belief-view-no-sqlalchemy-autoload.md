---
id: 20260723-belief-view-no-sqlalchemy-autoload
date: '2026-07-24'
project: cairn
domain: architecture
tags:
- sqlalchemy
- postgresql
- views
- codex
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
created_at: '2026-07-24 03:54:03.153106+00:00'
updated_at: '2026-07-24 03:55:23.802040+00:00'
---

# 20260723-belief-view-no-sqlalchemy-autoload

## decision

Keep the Codex belief typed-VIEW out of SQLAlchemy's autoload path; use raw SQL in service.py instead

## context

PR-B requires a 3-way UNION VIEW over decisions ∪ patterns ∪ observations. SQLAlchemy autoload would attempt to reflect the view as a mapped table, creating ORM coupling that complicates future schema evolution.

## reasoning

The belief view is a read-only projection for a specific query contract (search_knowledge() columns). Keeping it as raw SQL in service.py avoids ORM model drift, prevents accidental writes, and makes the view's purpose explicit at the call site.
