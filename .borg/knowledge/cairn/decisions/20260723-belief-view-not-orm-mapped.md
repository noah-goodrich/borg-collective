---
id: 20260723-belief-view-not-orm-mapped
date: '2026-07-24'
project: cairn
domain: architecture
tags:
- postgresql
- views
- sqlalchemy
- orm
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
created_at: '2026-07-24 05:15:46.520217+00:00'
updated_at: '2026-07-24 05:15:48.083615+00:00'
---

# 20260723-belief-view-not-orm-mapped

## decision

The `belief` typed-VIEW is implemented as a real `CREATE VIEW` queried via raw SQL in service.py, explicitly NOT ORM-mapped

## context

Needed a computed view over belief data including age_seconds calculation; had to choose between ORM mapping the view or raw SQL

## reasoning

Views with computed columns (especially time-based ones like age_seconds) don't map cleanly to SQLAlchemy ORM models; raw SQL keeps the view logic explicit and avoids ORM impedance mismatch for what is fundamentally a read-only projection
