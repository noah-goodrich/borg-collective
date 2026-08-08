---
id: obs-20260611-briefing-bats-stale-subcommand
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- bats
- testing
- borg-briefing
- subcommand-rename
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 20:39:25.161127+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-briefing-bats-stale-subcommand

## content

`tests/briefing.bats` calls `$BORG_CMD briefing` (lines 52/58/64/71/88/102/120) which returns exit 127 because the subcommand was replaced by `borg link --brief` in an earlier session. The 7 failures look like regressions to anyone who hasn't read the history, but they are pre-existing and unrelated to any lifecycle work.

## resolution

Mechanical fix: swap `$BORG_CMD briefing` → `$BORG_CMD link --brief` in those 7 lines. Not done in this session (out of scope); documented as next-session quick win (5 min).
