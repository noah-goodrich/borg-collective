---
id: obs-20260319-orm-models-schema-drift-risk
session_date: '2026-03-19'
project: cairn
tool: cursor
tags:
- sqlalchemy
- alembic
- orm
- schema
- migrations
category: domain_knowledge
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260611-1925-cairn
superseded_by: null
created_at: '2026-06-11 23:12:50.699973+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260319-orm-models-schema-drift-risk

## content

When using SQLAlchemy ORM models alongside Alembic migrations, there is a persistent risk of drift: a developer adds a column to an ORM model but forgets to generate a migration, or vice versa. The project explicitly chose migrations as the source of truth, meaning ORM models are intentionally a subset view.

## resolution

Enforce the convention via code review: any change to models_db.py must be accompanied by a new Alembic revision. Consider adding alembic check to CI to detect autogenerate drift (requires careful autogenerate configuration to avoid false positives from pgvector column types).
