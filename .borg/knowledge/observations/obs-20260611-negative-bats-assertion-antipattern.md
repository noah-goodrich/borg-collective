---
id: obs-20260611-negative-bats-assertion-antipattern
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- bats
- testing
- assertions
- shell
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.502905+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-negative-bats-assertion-antipattern

## content

The pattern `grep -qv PATTERN file || true` in a bats test always passes regardless of whether the pattern is absent. grep -v returns lines that don't match; if any line exists in the file, exit code is 0, so the assertion is a no-op. This produced a test that claimed to verify absence but actually verified nothing.

## resolution

Use `! grep -q PATTERN file` for negative assertions in bats. The `!` negates the exit code correctly and bats will fail the test if the pattern IS found.
