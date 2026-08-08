---
id: obs-20260616-cairn-stderr-discarded
session_date: '2026-06-16'
project: borg-collective
tool: claude-code
tags:
- cairn
- hooks
- stderr
- silent-failure
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.504989+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260616-cairn-stderr-discarded

## content

`borg-link-up.sh` was discarding cairn write stderr, making write failures completely invisible. The hook appeared to run successfully while cairn was receiving no data.

## resolution

PR #40 modified `borg-link-up.sh` to capture stderr. Any hook that writes to an external observability system should never discard stderr — silent failure in observability tooling means you lose data without knowing it.
