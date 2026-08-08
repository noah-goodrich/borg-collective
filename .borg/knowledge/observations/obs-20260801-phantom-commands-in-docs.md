---
id: obs-20260801-phantom-commands-in-docs
session_date: '2026-08-01'
project: borg-collective
tool: claude-code
tags:
- commands
- documentation
- borg-ship
- borg-assimilate
- drone-feature
- docs-sync
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: null
superseded_by: null
created_at: '2026-08-01 02:47:55.606962+00:00'
updated_at: '2026-08-01 02:47:55.606965+00:00'
---

# obs-20260801-phantom-commands-in-docs

## content

Multiple docs referenced commands that did not exist in the codebase: '/borg-ship' (correct: '/borg-assimilate') and 'drone start' (correct: 'drone feature'). These phantom commands were present in docs that appeared authoritative, including architecture docs.

## resolution

Caught during code-verification pass of the docs sync. All 14 files in PR #109 were checked against actual command implementations. Phantom commands replaced with correct names. Any docs sync must verify command names against source, not against other docs.
