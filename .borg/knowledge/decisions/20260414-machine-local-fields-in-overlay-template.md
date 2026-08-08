---
id: 20260414-machine-local-fields-in-overlay-template
date: '2026-06-11'
project: borg-collective
domain: architecture
tags:
- dotfiles
- settings-management
- claude-code
- cortex
- configuration
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 22:41:19.224343+00:00'
updated_at: '2026-06-11 22:41:19.224344+00:00'
---

# 20260414-machine-local-fields-in-overlay-template

## decision

Keep machine-local fields (model, enabledPlugins, cortexAgentConnectionName, theme) out of the versioned dotfiles base; generate them into a separate local overlay template on first borg setup run

## context

Claude Code and Cortex settings files mix universally-shared fields (permissions) with machine-specific fields (model choice, connection names). A single versioned file cannot serve both purposes.

## reasoning

Separating concerns means the versioned base can be updated and merged without risk of accidentally overwriting a developer's preferred model or connection name. The once-only template generation (guarded by if [[ ! -f ]]) pre-populates sensible defaults while still being editable.
