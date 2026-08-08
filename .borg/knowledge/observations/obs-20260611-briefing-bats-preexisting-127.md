---
id: obs-20260611-briefing-bats-preexisting-127
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- bats
- testing
- briefing
- subcommand
- exit-127
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.335785+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-briefing-bats-preexisting-127

## content

7 failures in briefing.bats are pre-existing and unrelated to the lifecycle inversion. They call `$BORG_CMD briefing` which no longer exists (replaced by `borg link --brief`), returning exit code 127. These failures are invisible noise that can mask real regressions if the total failure count is used as a health signal.

## resolution

Quick fix: replace `$BORG_CMD briefing` with `$BORG_CMD link --brief` in tests/briefing.bats lines 52/58/64/71/88/102/120. Explicitly deferred as out-of-scope for this session. Future sessions should fix this before adding new tests so the baseline is clean.
