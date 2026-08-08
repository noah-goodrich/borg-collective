---
id: obs-20260527-test-seeds-need-real-paths
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- bats
- testing
- registry
- state
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.495368+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260527-test-seeds-need-real-paths

## content

Registry seed data in lifecycle.bats used placeholder/hardcoded paths rather than TEST_CWD. After the Directive B migration, hooks began resolving state.json relative to the registry path, so tests that seeded fake paths silently wrote state.json to wrong locations (or failed to write at all), causing assertions on volatile fields to fail with confusing 'key not found' errors rather than value mismatches.

## resolution

Updated all registry seeds in lifecycle.bats to use real TEST_CWD-based paths. When registry entries point to filesystem locations that hooks will actually read/write, seeds must use paths that exist in the test environment.
