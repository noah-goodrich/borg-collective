---
id: obs-20260611-cp-dangling-symlink
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- cp
- symlink
- zsh
- CLAUDE.md
- setup
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.303953+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-cp-dangling-symlink

## content

cp does not reliably overwrite a dangling symlink with a real file. When the destination is a symlink whose target has been deleted, cp may error out or attempt to write to the missing target path, leaving the destination in a broken state. This manifested as CLAUDE.md missing after borg setup in projects that previously had a symlinked CLAUDE.md.

## resolution

Before any cp to a path that may be a symlink, check with '[ -L "$dest" ] && rm "$dest"' to ensure a clean destination.
