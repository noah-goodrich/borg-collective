---
id: obs-20260611-shim-retired-prematurely
session_date: '2026-06-11'
project: cairn
tool: cursor
tags:
- cairn
- shim
- hooks
- cli
- path
- restoration
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1925-cairn
superseded_by: null
created_at: '2026-06-11 23:12:50.733848+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-shim-retired-prematurely

## content

The dotfiles shell shim (~/.config/dotfiles/zsh/bin/cairn) was prematurely retired at some point before this session. The Python CLI is the correct tool for interactive use, but the shim is the *only* correct HTTP client for hook environments that use a stripped PATH and have no POSTGRES_PASSWORD. Retiring the shim broke all hook-based cairn calls across borg-collective, reveal, and cairn itself.

## resolution

Restored the shim. The shim must remain in place as the hook-environment cairn client. Do not retire it until the host Python CLI is migrated to HTTP transport.
