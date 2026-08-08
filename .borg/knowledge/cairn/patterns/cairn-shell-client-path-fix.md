---
id: cairn-shell-client-path-fix
project: cairn
domain: ops
tags:
- shell
- cli
- hooks
- path
- borg
preconditions: []
steps:
- The shim lives at ~/.config/dotfiles/zsh/bin/cairn and must resolve curl and jq
  to absolute paths at startup.
- Add absolute path resolution at the top of the shim (e.g., CURL=$(command -v curl)
  and JQ=$(command -v jq)).
- Ensure ~/.config/dotfiles/zsh/bin is prepended to PATH in borg-link-down.sh and
  borg-link-up.sh hook scripts.
pitfalls:
- Claude Code strips PATH to a minimal sandbox — hooks that rely on bare curl or jq
  will silently fail.
- 'The Python CLI and the shell shim are two different executables: ~/.local/bin/cairn
  (direct-Postgres) vs ~/.config/dotfiles/zsh/bin/cairn (HTTP). Retiring the shim
  breaks hook-environment calls.'
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260610-1630-cairn
superseded_by: null
created_at: '2026-06-10 16:50:37.419828+00:00'
updated_at: '2026-06-10 16:50:37.419829+00:00'
---

# cairn-shell-client-path-fix

## description

Fix the cairn shell shim when it fails to resolve curl/jq in Claude Code sandbox, cron, or non-interactive container shells.
