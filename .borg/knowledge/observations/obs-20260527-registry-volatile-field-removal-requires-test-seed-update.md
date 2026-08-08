---
id: obs-20260527-registry-volatile-field-removal-requires-test-seed-update
session_date: '2026-06-16'
project: borg-collective
tool: claude-code
tags:
- borg-collective
- testing
- bats
- registry
- state
category: pattern_discovered
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.459081+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260527-registry-volatile-field-removal-requires-test-seed-update

## content

When volatile fields are removed from the registry schema, existing bats test seeds that hardcode those fields (e.g. claude_session_id, status in registry JSON fixtures) will silently pass or fail depending on whether the assertions also reference the moved fields. Tests that read volatile state must be updated to read from state.json rather than the registry, and registry seeds must use real TEST_CWD paths so path-dependent helpers resolve correctly.

## resolution

Audit all registry seed fixtures and volatile-field assertions together when changing the schema boundary. In this session: updated lifecycle.bats seeds to use real TEST_CWD paths, redirected volatile-field assertions to state.json, and added a dedicated state.bats suite (14 tests) to cover the new helpers explicitly.
