---
id: obs-20260630-cursor-logic-drift-risk
session_date: '2026-06-30'
project: borg-collective
tool: claude-code
tags:
- vinculum
- cursor
- refactoring
- technical-debt
category: domain_knowledge
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260630-2202-borg-collective
superseded_by: null
created_at: '2026-06-30 22:03:12.822101+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260630-cursor-logic-drift-risk

## content

The cursor read/write logic in `borg.zsh` is inlined at 4 separate callsites. The watcher binary (`borg-vinculum-watch`) already encapsulates this logic correctly. As the codebase evolves, the 4 inlined copies will drift from each other and from the watcher's implementation.

## resolution

Deferred but identified: extract `_read_cursor` and `_write_cursor` helper functions in `borg.zsh` and call them from all 4 sites. This is a known follow-up task for a future session.
