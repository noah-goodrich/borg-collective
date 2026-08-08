---
id: obs-20260721-additive-migration-safe-for-deployed-image
session_date: '2026-07-21'
project: cairn
tool: claude-code
tags:
- alembic
- migrations
- production
- deployment
- backward-compatibility
category: domain_knowledge
files_involved: []
confidence: 0.7
source_model: null
source_session: null
superseded_by: null
created_at: '2026-07-24 03:53:11.051474+00:00'
updated_at: '2026-07-24 03:55:24.084484+00:00'
---

# obs-20260721-additive-migration-safe-for-deployed-image

## content

Migration 008 (adding nullable FK columns superseded_by + updated_at with DEFAULT, plus triggers) is safe to defer applying to prod even when the new image is deployed, because: (1) all reads use raw SQL with explicit column lists, (2) all inserts use explicit column lists (not INSERT INTO ... SELECT *), (3) added columns have safe defaults. The deployed image neither breaks on the old schema nor requires the new columns for existing functionality.

## resolution

Document additive migration compatibility explicitly in migration files when deferring prod apply. The key invariants are: no SELECT *, no positional column assumptions, nullable or defaulted new columns.
