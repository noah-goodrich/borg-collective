---
id: obs-20260423-dangling-symlink-blocks-cp
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- shell
- zsh
- symlink
- cp
- claude-md
- borg-setup
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 20:39:25.116154+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260423-dangling-symlink-blocks-cp

## content

If CLAUDE.md exists as a dangling symlink (target deleted), cp will fail with an error rather than overwriting the symlink. This blocked borg setup on the work machine after a previous partial install left a broken symlink.

## resolution

Before cp-ing to a destination, explicitly check for and remove dangling symlinks: `[ -L "$dest" ] && [ ! -e "$dest" ] && rm "$dest"`. Run this before any cp that might target a previously-symlinked path.
