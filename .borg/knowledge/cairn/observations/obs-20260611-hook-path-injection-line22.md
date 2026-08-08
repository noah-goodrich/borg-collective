---
id: obs-20260611-hook-path-injection-line22
session_date: '2026-06-11'
project: cairn
tool: cursor
tags:
- cairn
- hooks
- path
- dotfiles
- borg
category: domain_knowledge
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1925-cairn
superseded_by: null
created_at: '2026-06-11 20:31:18.026331+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-hook-path-injection-line22

## content

Hook environments receive a stripped PATH. The dotfiles bin directory (~/.config/dotfiles/zsh/bin) is injected at line 22 of the hook PATH configuration. This is the mechanism that makes the cairn shim available in hooks. If the shim is absent from that directory, all hook integrations (borg-collective, reveal, cairn) will report CAIRN UNAVAILABLE.

## resolution

Verify shim presence before any dotfiles bin directory cleanup: ls ~/.config/dotfiles/zsh/bin/cairn. Never retire the shim without first confirming hooks have an alternative client path.
