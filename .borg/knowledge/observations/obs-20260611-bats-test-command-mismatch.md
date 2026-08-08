---
id: obs-20260611-bats-test-command-mismatch
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- bats
- testing
- briefing
- cli
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 20:39:25.149673+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-bats-test-command-mismatch

## content

tests/briefing.bats was testing '$BORG_CMD briefing' but the actual command surface had changed to '$BORG_CMD link --brief'. The tests were passing against a stale command path, meaning the actual production path (link --brief) was untested.

## resolution

Updated 7 lines + header comment in briefing.bats to use '$BORG_CMD link --brief'. All 8 briefing tests green; full suite 141/141. When renaming or restructuring CLI commands, grep test files for the old command name before closing the PR.
