---
id: obs-20260611-cairn-write-stderr-discarded
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- cairn
- shell
- stderr
- silent-failure
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.522402+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-cairn-write-stderr-discarded

## content

`borg-link-up.sh` was discarding cairn write stderr entirely, so cairn write failures were silent — the hook exited 0 and left no trace. This made the cairn write failures diagnosed in this session invisible until the stderr capture was added.

## resolution

PR #40 added stderr capture to `borg-link-up.sh`. Any script invoking `cairn write` should capture and surface stderr on failure, not discard it.
