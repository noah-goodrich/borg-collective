---
id: obs-20260721-contradiction-tests-on-fixtures-not-corpus
session_date: '2026-07-21'
project: cairn
tool: claude-code
tags:
- testing
- contradiction-detection
- fixtures
- codex
category: domain_knowledge
files_involved: []
confidence: 0.7
source_model: null
source_session: null
superseded_by: null
created_at: '2026-07-21 22:17:44.756497+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260721-contradiction-tests-on-fixtures-not-corpus

## content

Scope Hawk and Skeptic converged that contradiction detection tests in Phase 1a should run against seeded fixtures, not the live corpus. Testing against the corpus introduces non-determinism (corpus content changes) and makes test failures ambiguous.

## resolution

Seed a small, stable fixture set that includes at least one known contradiction pair. Tests assert on the fixture output only. Corpus-scale contradiction queries are a Phase 1b concern.
