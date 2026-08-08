---
id: shell-client-absolute-path-resolution
project: cairn
domain: infrastructure
tags:
- shell-scripting
- PATH
- devcontainers
- cron
- portability
preconditions: []
steps:
- 'At the top of the script, resolve all external tool dependencies to absolute paths
  using `command -v` or hardcoded paths: `CURL=$(command -v curl)`, `JQ=$(command
  -v jq)`'
- 'Prepend known tool directories to PATH before any tool invocations: `export PATH="$HOME/.config/dotfiles/zsh/bin:$PATH"`'
- Use the resolved absolute-path variables throughout the script instead of bare command
  names
- 'Test the script by calling it from a minimal environment: `env -i HOME=$HOME PATH=/usr/bin:/bin
  bash -c ''/path/to/script''`'
pitfalls:
- Claude Code and cron run with heavily stripped PATH — tools present in interactive
  shells are simply not found
- The failure mode is `command not found` for curl or jq, making the entire client
  silently no-op rather than giving a useful error
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1925-cairn
superseded_by: null
created_at: '2026-06-11 20:31:17.997933+00:00'
updated_at: '2026-06-11 20:31:17.997933+00:00'
---

# shell-client-absolute-path-resolution

## description

Pattern for writing shell utility scripts that work in stripped environments (cron, Claude Code sandbox, non-interactive containers)
