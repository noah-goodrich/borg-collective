---
id: 20260611-shim-vs-python-cli-for-hooks
date: '2026-06-11'
project: cairn
domain: architecture
tags:
- cairn
- cli
- hooks
- http
- postgres
- environment
alternatives: []
applies_to: []
confidence: 0.9
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1925-cairn
created_at: '2026-06-11 20:31:18.024077+00:00'
updated_at: '2026-06-11 20:31:18.024077+00:00'
---

# 20260611-shim-vs-python-cli-for-hooks

## decision

Hook environments use the shell shim (HTTP client) at ~/.config/dotfiles/zsh/bin/cairn, not the Python CLI at ~/.local/bin/cairn. The shim is the correct client for hook contexts.

## context

The cairn restoration directive required verifying that hooks in borg-collective, reveal, and cairn projects could reach cairn. The Python CLI goes direct-Postgres and requires POSTGRES_PASSWORD in the environment. Hook environments have a stripped PATH and no POSTGRES_PASSWORD.

## reasoning

Shell shim speaks HTTP to the cairn server and requires no database credentials. Hook environments only have the dotfiles bin directory injected into PATH (line 22 of hook PATH config), so the shim is naturally available. The Python CLI would fail silently or error due to missing credentials in those stripped environments.
