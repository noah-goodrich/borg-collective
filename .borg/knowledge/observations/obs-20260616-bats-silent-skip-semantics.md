---
id: obs-20260616-bats-silent-skip-semantics
session_date: '2026-06-16'
project: borg-collective
tool: claude-code
tags:
- bats
- testing
- cairn
- hooks
- silent-skip
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.221414+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260616-bats-silent-skip-semantics

## content

Three bats tests were asserting the wrong expected output for the 'cairn binary absent' scenario. The hooks implement silent-skip (no output, exit 0) when cairn is not found, but the tests expected an error message. This caused 3/141 tests to fail. The bug was masked because the tests ran in an environment where cairn was present, so the absent-binary branch was never exercised by the real binary path.

## resolution

Updated tests to use `env PATH=...` to guarantee cairn is absent, and updated expected output to match actual silent-skip behavior (empty output, exit 0). Always run absent-binary tests with explicit PATH control.
