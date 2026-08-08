---
id: cli-service-integration-test-with-real-db
project: cairn
domain: testing
tags:
- integration-testing
- pgvector
- embeddings
- cli
- real-db
preconditions: []
steps:
- Spin up a real Postgres+pgvector instance (or use the CI service container)
- Call the CLI record_* function under test (e.g., record_decision) with a known payload
- Query the database directly to assert the embedding column is non-NULL
- Run a semantic search query and assert the newly recorded item appears in results
- Keep the service layer mock-free so embedding generation is exercised end-to-end
pitfalls:
- Mocking at the db layer instead of the service layer will hide NULL-embedding bugs
  — mock only external I/O (network, auth), not the embedding pipeline
- pgvector must be installed in the test Postgres instance; a plain Postgres image
  will cause silent failures or schema errors
- If the embedding model requires network access, tests will fail in air-gapped CI
  without a stub or cached model
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1925-cairn
superseded_by: null
created_at: '2026-06-11 20:31:18.035180+00:00'
updated_at: '2026-06-11 20:31:18.035181+00:00'
---

# cli-service-integration-test-with-real-db

## description

Verify that a CLI entry point produces records with non-NULL embeddings that are returned by semantic search, using a real Postgres+pgvector database rather than mocks
