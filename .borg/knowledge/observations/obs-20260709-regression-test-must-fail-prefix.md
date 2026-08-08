---
id: obs-20260709-regression-test-must-fail-prefix
session_date: '2026-07-09'
project: borg-collective
tool: claude-code
tags:
- testing
- bats
- regression
- tdd
category: pattern_discovered
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260709-0431-orchestrator
superseded_by: null
created_at: '2026-07-09 15:26:37.446098+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260709-regression-test-must-fail-prefix

## content

A regression test for a silent-exit-0 bug is only meaningful if it can be shown to fail against the pre-fix code. If the test passes against both old and new code, it is a tautology. During this session, the missing-binary test was explicitly verified to fail against the pre-fix script (which exited 0), confirming it is a real regression pin.

## resolution

When adding tests for silent-failure bugs, always run the new test against the pre-fix version of the code as part of the PR process to confirm the test actually catches the regression.
