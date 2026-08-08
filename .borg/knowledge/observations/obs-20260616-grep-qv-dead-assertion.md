---
id: obs-20260616-grep-qv-dead-assertion
session_date: '2026-06-16'
project: borg-collective
tool: claude-code
tags:
- bats
- testing
- grep
- negative-assertion
- shell
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.467579+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260616-grep-qv-dead-assertion

## content

Using 'grep -qv PATTERN <<< "$output" || true' as a negative assertion in bats is completely inert. grep -qv succeeds whenever ANY line lacks the pattern (almost always true for multi-line output), and || true suppresses the exit code anyway. The test will never fail even if the pattern is present.

## resolution

Replace with '! grep -q "PATTERN" <<< "$output"' — this is the correct bats idiom for asserting absence. The ! negates grep's exit code directly without suppression.
