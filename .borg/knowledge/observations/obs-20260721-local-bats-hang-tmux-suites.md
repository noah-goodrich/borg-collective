---
id: obs-20260721-local-bats-hang-tmux-suites
session_date: '2026-07-21'
project: borg-collective
tool: claude-code
tags:
- bats
- tmux
- ci
- local-dev
- environment
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: null
superseded_by: null
created_at: '2026-07-21 22:16:47.851620+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260721-local-bats-hang-tmux-suites

## content

Running the full bats test suite (bats tests/*.bats) locally hangs on container/tmux-dependent suites in a stateful host environment. This is not a code defect — the suite passes cleanly on CI runners.

## resolution

Run only the targeted suite (bats tests/usage_watch.bats) locally for fast feedback. Rely on CI for the full suite. Do not interpret a local hang as a test failure — check CI before raising an alarm.
