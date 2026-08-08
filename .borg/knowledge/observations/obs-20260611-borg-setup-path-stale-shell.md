---
id: obs-20260611-borg-setup-path-stale-shell
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- borg
- PATH
- zsh
- shell-restart
- setup-warning
category: tool_behavior
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.561336+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-borg-setup-path-stale-shell

## content

`borg setup` emitted a warning that `~/.claude/bin` was not on PATH, but inspection of `zsh/.zshrc:81` confirmed the export was already present. The warning was a false positive caused by running in a shell session started before the dotfiles change was sourced.

## resolution

No dotfiles edit required. Shell restart resolves it. When `borg setup` warns about PATH, check whether the current shell predates the relevant `.zshrc` change before editing any config.
