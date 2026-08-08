---
id: obs-20260418-tmux-target-session-name
session_date: '2026-04-18'
project: borg-collective
tool: cursor
tags:
- tmux
- cli
- targeting
- session-management
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.279140+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260418-tmux-target-session-name

## content

When addressing a tmux window by index (e.g., window 2), the correct target syntax is `<session-name>:<window-index>` — for example `borg:2`. Using a bare integer like `-t 2:ingle` silently treats `2` as the session name and fails. The session in this project is named `borg`, not a number, so all window targets must be prefixed with `borg:`.


## resolution

Run `tmux list-windows -a` to confirm the session name and window indices before issuing any `tmux select-layout`, `send-keys`, or similar commands. Always use the fully-qualified `<session>:<window>` form.

