---
id: obs-20260616-path-warning-stale-shell
session_date: '2026-06-16'
project: borg-collective
tool: claude-code
tags:
- path
- zsh
- borg
- claude-plugins
- shell-restart
category: tool_behavior
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.555900+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260616-path-warning-stale-shell

## content

`borg setup` emitted a warning that `~/.claude/bin` was not on PATH. Inspection of `zsh/.zshrc:81` confirmed the export is already present. The warning was a false positive caused by the current shell session predating the dotfiles commit that added the PATH line — the line was already in the file.

## resolution

No edit required. Shell restart (planned for end of session) will source the updated .zshrc and clear the warning. Do not add duplicate PATH entries in response to this warning without first confirming the line is absent from .zshrc.
