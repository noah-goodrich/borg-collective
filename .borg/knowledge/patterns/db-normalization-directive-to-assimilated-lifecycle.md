---
id: db-normalization-directive-to-assimilated-lifecycle
project: borg-collective
domain: architecture
tags:
- borg-collective
- directives
- workflow
- documentation
preconditions: []
steps:
- Create directive in `docs/plans/directives/` describing all breaking schema changes
- Write and apply migrations sequentially; document each in the directive
- Run `/simplify` on migration files to catch comment/dedup issues before they are
  permanent
- Run `/borg-assimilate` for Collective review; action any follow-up items
- 'Generate schema docs: ERD (Mermaid) + per-table files under `docs/schema/`'
- Create frontend migration guide documenting breaking changes, new query patterns,
  and fallback handling
- 'Archive directive: move from `docs/plans/directives/` to `docs/plans/assimilated/`'
pitfalls:
- '`/simplify` findings on already-applied migrations are non-fixable without a new
  migration; only unfixed issues in pending files can be corrected in place'
- Frontend guide must explicitly document nullable FK columns (e.g., canonical_item_id
  IS NULL) or frontend developers will assume FKs are always populated
- Orphan seed rows must be deleted before FK validation — missing this blocks `VALIDATE
  CONSTRAINT`
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.411848+00:00'
updated_at: '2026-06-11 22:41:19.411848+00:00'
---

# db-normalization-directive-to-assimilated-lifecycle

## description

Full lifecycle for a borg-collective database normalization directive: from active directive → migrations applied → frontend guide created → schema docs generated → directive archived as assimilated.
