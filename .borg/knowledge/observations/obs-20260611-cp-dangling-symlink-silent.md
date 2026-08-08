---
id: obs-20260611-cp-dangling-symlink-silent
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- cp
- symlink
- zsh
- borg.zsh
- setup
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 20:39:25.100415+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-cp-dangling-symlink-silent

## content

cp silently 'succeeds' when the destination is a dangling symlink, writing to the symlink's (nonexistent) target rather than replacing the symlink itself. No error is returned. This caused setup to appear to complete successfully while CLAUDE.md was never actually written to the expected location.

## resolution

Added an explicit dangling symlink check and removal (rm) before every cp in _borg_merge_claude_md. Released as v0.7.5.
