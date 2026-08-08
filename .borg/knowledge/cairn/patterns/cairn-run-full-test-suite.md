---
id: cairn-run-full-test-suite
project: cairn
domain: testing
tags:
- testing
- pytest
- docker
- devcontainer
preconditions: []
steps:
- 'Run all tests: drone exec cairn -- pytest'
- 'Run with coverage: drone exec cairn -- pytest --cov'
- 'Run lint (ruff + sqlfluff): drone exec cairn -- cairn-lint'
- 'Run formatter: drone exec cairn -- cairn-format'
- 'Run migration integration tests specifically: drone exec cairn -- pytest tests/test_migration.py
  -v'
pitfalls:
- 'cairn_test database must exist before test_migration.py runs — create it manually:
  psql -U dev -d postgres -c ''CREATE DATABASE cairn_test;'''
- conftest.py was empty until v0.2 real-DB fixture tier — earlier test runs have no
  transactional rollback fixtures.
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260610-1630-cairn
superseded_by: null
created_at: '2026-06-10 16:50:37.419048+00:00'
updated_at: '2026-06-10 16:50:37.419049+00:00'
---

# cairn-run-full-test-suite

## description

Run the full cairn test suite and lint checks inside the devcontainer.
