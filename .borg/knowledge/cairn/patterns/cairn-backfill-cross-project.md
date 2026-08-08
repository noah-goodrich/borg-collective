---
id: cairn-backfill-cross-project
project: cairn
domain: knowledge-management
tags:
- cairn
- backfill
- semantic-search
- knowledge-graph
preconditions: []
steps:
- Collect input documents per project into cairn/backfill-input/ (do not commit —
  gitignore or delete after)
- Run backfill pipeline per project, verifying record counts after each batch
- After all projects are loaded, run cross-project semantic search queries to confirm
  index integrity
- Record pre/post counts (e.g. 347 → 1,395) for audit trail
pitfalls:
- backfill-input/ directory should not be committed — contains raw data that may be
  sensitive; add to .gitignore immediately
- Verify GHCR image is public and multi-arch before running backfill against a containerized
  cairn instance
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1925-cairn
superseded_by: null
created_at: '2026-06-12 03:25:39.253853+00:00'
updated_at: '2026-06-12 03:25:39.253854+00:00'
---

# cairn-backfill-cross-project

## description

Pattern for bulk-backfilling a cairn knowledge graph from multiple projects and verifying cross-project semantic search
