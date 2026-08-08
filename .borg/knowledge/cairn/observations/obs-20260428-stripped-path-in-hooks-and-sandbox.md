---
id: obs-20260428-stripped-path-in-hooks-and-sandbox
session_date: '2026-06-11'
project: cairn
tool: cursor
tags:
- PATH
- claude-code
- hooks
- cron
- shell
- devcontainers
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1925-cairn
superseded_by: null
created_at: '2026-06-11 20:31:17.999049+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260428-stripped-path-in-hooks-and-sandbox

## content

Claude Code sessions, borg hooks, and cron jobs all run with a minimal PATH that does not include user-installed tool locations like ~/.config/dotfiles/zsh/bin. Shell scripts that work fine interactively fail silently or with `command not found` in these contexts. Both the cairn shell client and the borg hook scripts were affected.

## resolution

Explicitly prepend required PATH entries at the top of each script before any tool invocations. For the cairn client, also resolve curl and jq to absolute paths at startup using `command -v`.
