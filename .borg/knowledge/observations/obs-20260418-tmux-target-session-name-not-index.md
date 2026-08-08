---
id: obs-20260418-tmux-target-session-name-not-index
session_date: '2026-04-18'
project: borg-collective
tool: cursor
tags:
- tmux
- cli
- target-syntax
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 20:39:25.069984+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260418-tmux-target-session-name-not-index

## content

When a tmux session is named (e.g. 'borg'), targeting a window as '2:ingle' fails because tmux interprets '2' as a session name, not the named session's index. The correct target syntax is 'borg:2' (or 'borg:ingle'). Diagnosis: run `tmux list-windows -a` to confirm fully-qualified session:window names before issuing layout or send-keys commands.


## resolution

Self-corrected by running `tmux list-windows -a` and switching the target from '-t 2:ingle' to '-t borg:2'. No data loss — cosmetic layout command only.

