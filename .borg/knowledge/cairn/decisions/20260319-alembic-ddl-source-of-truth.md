---
id: 20260319-alembic-ddl-source-of-truth
date: '2026-06-11'
project: cairn
domain: architecture
tags:
- alembic
- sqlalchemy
- migrations
- schema
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1925-cairn
created_at: '2026-06-11 20:31:17.982062+00:00'
updated_at: '2026-06-11 20:31:17.982063+00:00'
---

# 20260319-alembic-ddl-source-of-truth

## decision

All DDL lives in Alembic migrations; ORM models (Base) are used only for type-safe inserts, not schema creation

## context

When introducing SQLAlchemy ORM alongside Alembic, a choice must be made about where schema is defined

## reasoning

Avoids drift between ORM model definitions and actual database schema; Alembic migration is the single source of truth for what the DB actually contains
