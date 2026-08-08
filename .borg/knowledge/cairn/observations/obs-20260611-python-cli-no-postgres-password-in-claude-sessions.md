---
id: obs-20260611-python-cli-no-postgres-password-in-claude-sessions
session_date: '2026-06-11'
project: cairn
tool: cursor
tags:
- cairn
- cli
- postgres
- credentials
- claude-code
- environment
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1925-cairn
superseded_by: null
created_at: '2026-06-11 20:31:18.025980+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-python-cli-no-postgres-password-in-claude-sessions

## content

The Python cairn CLI (~/.local/bin/cairn) requires POSTGRES_PASSWORD in the environment. Claude Code sessions do not inherit POSTGRES_PASSWORD (it comes from local.zsh which is only sourced in interactive terminals). This means `cairn search` and `cairn record` via the Python CLI silently fail or error in Claude Code/Cursor sessions unless the variable is explicitly set.

## resolution

Use the shell shim for any cairn operations inside Claude Code sessions, or prefix commands with the password: POSTGRES_PASSWORD=... cairn search ... . Long-term fix is routing the Python CLI through HTTP instead of direct-Postgres, deferred post-v0.2.
