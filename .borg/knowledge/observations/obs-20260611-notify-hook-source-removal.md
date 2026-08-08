---
id: obs-20260611-notify-hook-source-removal
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- plugin
- hooks
- notify
- dependency-reduction
category: domain_knowledge
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.523382+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-notify-hook-source-removal

## content

The `hooks/notify.sh` in `claude-plugins` was sourcing `$HOME/.claude/lib/borg-hooks.sh` to get `_borg_osa_notify`, creating an implicit runtime dependency on the borg-collective installation path. Inlining the function removes this fragile coupling.

## resolution

Inlined `_borg_osa_notify` directly into `hooks/notify.sh`. Plugin files should be self-contained and not source paths outside the plugin directory.
