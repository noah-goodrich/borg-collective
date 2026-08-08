---
id: obs-20260414-dotfiles-base-must-exclude-machine-local-fields
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- dotfiles
- settings-management
- claude-code
- cortex
- portability
category: domain_knowledge
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 20:39:24.980340+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260414-dotfiles-base-must-exclude-machine-local-fields

## content

Claude Code's settings.json and Cortex's settings.json both mix portable config (permissions) with machine-specific or user-preference fields (model, enabledPlugins, cortexAgentConnectionName, theme). If the dotfiles base includes these fields, borg setup will either overwrite correct machine values with wrong defaults or require per-machine dotfiles branches. The versioned base must contain only the portable subset.

## resolution

Stripped model and enabledPlugins from dotfiles/claude/code/settings.json. Created a separate local overlay template pattern for machine-specific fields. Applied the same split to Cortex with settings.base.json vs cortex-settings.local.json.
