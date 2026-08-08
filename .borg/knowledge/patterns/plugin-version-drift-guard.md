---
id: plugin-version-drift-guard
project: borg-collective
domain: build-tooling
tags:
- plugin
- versioning
- drift
- bats
- build-script
preconditions: []
steps:
- Store canonical version in a single VERSION file at repo root
- Update build-plugin.sh to read VERSION file and inject into plugin manifest at build
  time
- Add a drift-guard check in build-plugin.sh that fails loudly if any hardcoded version
  strings are found out of sync
- 'Write 5 bats tests covering: version injection, drift detection triggering, drift
  detection passing, build output correctness, and idempotency'
- Run bats suite in CI to gate merges
pitfalls:
- Plugin manifests may have version strings in multiple locations — drift-guard must
  cover all of them
- bats tests need to run against the built artifact, not just the script, to catch
  injection failures
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-12 03:25:39.252883+00:00'
updated_at: '2026-06-12 03:25:39.252883+00:00'
---

# plugin-version-drift-guard

## description

Pattern for keeping plugin versions derived from a single VERSION source of truth with drift detection and automated tests
