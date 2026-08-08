---
id: obs-20260611-bats-path-isolation
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- bats
- testing
- PATH
- shell-hooks
- cairn
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.341235+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-bats-path-isolation

## content

BATS tests for 'cairn absent' scenarios were failing because the test environment inherited the real PATH which included cairn. Tests intended to verify silent-skip behaviour when cairn is not installed would pass locally only when cairn happened to be absent from the machine. The fix required explicitly isolating PATH with `env PATH=...` to exclude the cairn binary.

## resolution

For any BATS test that asserts behaviour when an optional dependency is absent, override PATH inline: `run env PATH=/usr/bin:/bin <command>` so the test is hermetic regardless of what is installed on the host.
