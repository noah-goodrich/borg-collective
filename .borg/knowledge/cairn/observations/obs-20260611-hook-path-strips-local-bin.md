---
id: obs-20260611-hook-path-strips-local-bin
session_date: '2026-06-11'
project: cairn
tool: cursor
tags:
- hooks
- path
- cairn
- environment
- dotfiles
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1925-cairn
superseded_by: null
created_at: '2026-06-11 23:12:50.734222+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-hook-path-strips-local-bin

## content

Hook environments (git hooks, borg hooks, etc.) use a stripped PATH that does not include ~/.local/bin, where the Python cairn CLI lives. The hook PATH does include ~/.config/dotfiles/zsh/bin (confirmed via line 22 of the hook PATH config), which is where the shell shim lives.

## resolution

Always verify cairn availability in hooks via the shim path, not the Python CLI path. When diagnosing 'CAIRN UNAVAILABLE' errors in hooks, check whether the shim exists and is executable before investigating the server.
