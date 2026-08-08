---
id: obs-20260611-claude-code-no-postgres-password
session_date: '2026-06-11'
project: cairn
tool: cursor
tags:
- cairn
- claude-code
- postgres
- credentials
- environment
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1925-cairn
superseded_by: null
created_at: '2026-06-11 23:12:50.734548+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-claude-code-no-postgres-password

## content

Claude Code sessions do not inherit POSTGRES_PASSWORD from the shell environment, so any cairn operation routed through the Python CLI (direct-Postgres) silently fails or errors. This means `cairn search` and `cairn record` called from within a Claude Code tool invocation will fail unless the session was started from an interactive terminal that sourced local.zsh.

## resolution

For Claude Code contexts, use the HTTP shim or ensure POSTGRES_PASSWORD is explicitly passed. Long-term fix is migrating the host CLI to HTTP transport. In the interim, be aware that cairn search results from Claude Code sessions may be empty due to auth failure rather than missing knowledge.
