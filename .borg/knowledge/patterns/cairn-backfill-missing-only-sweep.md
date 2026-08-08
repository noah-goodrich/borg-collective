---
id: cairn-backfill-missing-only-sweep
project: borg-collective
domain: data-engineering
tags:
- cairn
- knowledge-graph
- backfill
- embeddings
- idempotent
preconditions: []
steps:
- Query cairn DB to identify which source files have zero records (missing) vs. already-extracted
  files.
- Run extraction sweep scoped to missing files only (skip files with existing records).
- Quarantine deterministically malformed files (e.g., broken YAML) rather than aborting
  the sweep.
- After extraction, run re-embedding in chunked batches (e.g., 50/batch) to avoid
  OOM on large graphs.
- 'Validate: confirm 0 NULL embeddings, check record counts by type (decisions/patterns/observations),
  run a semantic search spot-check on newly added records.'
- Normalize any project name inconsistencies found during QA (e.g., `stillpoint-labs`
  → `stillpointlabs-site`) before final commit.
pitfalls:
- Malformed YAML in source files will cause the entire sweep to abort if not quarantined
  — detect and skip deterministically bad files rather than failing the run.
- Re-embedding the full graph in one batch causes OOM on large graphs — always chunk
  embedding calls.
- Record counts can appear inflated by duplicate detection — verify idempotent skips
  separately from new inserts.
- Semantic search spot-check is necessary — embedding completion (0 NULL) does not
  guarantee the embeddings are semantically correct.
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-17 18:01:10.022212+00:00'
updated_at: '2026-06-17 18:01:10.022213+00:00'
---

# cairn-backfill-missing-only-sweep

## description

Run a targeted extraction sweep over only files missing from the cairn knowledge graph, then re-embed in batches to avoid OOM, and validate completeness before committing.
