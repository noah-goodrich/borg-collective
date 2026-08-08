---
id: obs-20260428-stripped-path-hook-failure
session_date: '2026-06-11'
project: cairn
tool: cursor
tags:
- shell
- PATH
- hooks
- claude-code
- cron
- devcontainer
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1925-cairn
superseded_by: null
created_at: '2026-06-11 23:12:50.709583+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260428-stripped-path-hook-failure

## content

Shell hooks (borg-link-down.sh, borg-link-up.sh) and the cairn shell client silently fail in Claude Code sandbox and non-interactive container shells because those environments have a stripped PATH that does not include ~/.config/dotfiles/zsh/bin or even standard locations for curl and jq.

## resolution

Prepend the dotfiles bin directory at the top of each hook and resolve curl/jq to absolute paths at startup in the shell client. Changes needed in both hook files and the cairn client script.
