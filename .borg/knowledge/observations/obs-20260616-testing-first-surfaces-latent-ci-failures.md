---
id: obs-20260616-testing-first-surfaces-latent-ci-failures
session_date: '2026-06-16'
project: borg-collective
tool: claude-code
tags:
- testing
- ci
- tdd
- latent-bugs
category: pattern_discovered
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.544870+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260616-testing-first-surfaces-latent-ci-failures

## content

The testing-first discipline adopted this session surfaced 4 bugs that passed locally but failed in CI. These bugs had been latent (some since PR #46). Without the explicit requirement to make CI green before merging, they would have continued to accumulate.

## resolution

All 4 were fixed before merging. The pattern reinforces: local green is insufficient; CI must be green and the CI environment must match the target deployment environment (OS, PG version, DB name).
