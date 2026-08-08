---
id: obs-20260611-cairn-absent-test-path-leak
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- bats
- PATH
- test-isolation
- cairn
- false-positive
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.348569+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-cairn-absent-test-path-leak

## content

Bats tests asserting 'binary not found' behavior will silently pass on a clean CI machine but fail on any developer machine (or container) where the binary under test is installed, because the test inherits the host PATH. This caused 3/141 tests to fail intermittently depending on environment.

## resolution

Always override PATH inline for any bats test that needs to simulate a missing binary: `PATH=/usr/bin:/bin run my-script`. Do not rely on the binary being absent from the environment.
