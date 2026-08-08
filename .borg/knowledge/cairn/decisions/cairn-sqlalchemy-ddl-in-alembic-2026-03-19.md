---
id: cairn-sqlalchemy-ddl-in-alembic-2026-03-19
date: '2026-06-10'
project: cairn
domain: db
tags:
- postgres
- sqlalchemy
- alembic
- architecture
alternatives: []
applies_to: []
confidence: 0.95
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260610-1630-cairn
created_at: '2026-06-10 16:50:37.411099+00:00'
updated_at: '2026-06-10 16:50:37.411101+00:00'
---

# cairn-sqlalchemy-ddl-in-alembic-2026-03-19

## decision

All DDL lives in Alembic migrations, not in Base.metadata.create_all(). ORM models exist only for type-safe inserts.

## context

Replacing raw psycopg layer with SQLAlchemy 2.0 + Alembic raised the question of where schema truth lives.

## reasoning

Keeps ORM and actual schema in sync; avoids silent drift between the ORM definition and what Postgres actually has.
