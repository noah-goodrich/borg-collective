---
id: 20260611-python-cli-direct-postgres-mismatch
date: '2026-06-11'
project: cairn
domain: architecture
tags:
- cairn
- cli
- postgres
- credentials
- claude-code
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1925-cairn
created_at: '2026-06-11 23:12:50.732777+00:00'
updated_at: '2026-06-11 23:12:50.732777+00:00'
---

# 20260611-python-cli-direct-postgres-mismatch

## decision

Accept the credential mismatch for now: Python CLI requires POSTGRES_PASSWORD (only available in interactive shells sourcing local.zsh), while the HTTP shim works credential-free

## context

Claude Code sessions do not inherit POSTGRES_PASSWORD, so `cairn search` from a Claude Code session fails when routed through the Python CLI. Interactive terminals work because local.zsh sources the password.

## reasoning

The gap is non-blocking for v0.2 — hooks use the shim, interactive use works, and the fix (migrating the host CLI to HTTP) is a future scope item.
