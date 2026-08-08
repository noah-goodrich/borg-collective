---
id: 20260414-machine-local-fields-in-overlay-templates
date: '2026-06-11'
project: borg-collective
domain: architecture
tags:
- dotfiles
- settings-management
- portability
- claude-code
- cortex
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 20:39:24.977988+00:00'
updated_at: '2026-06-11 20:39:24.977989+00:00'
---

# 20260414-machine-local-fields-in-overlay-templates

## decision

Keep machine-variable fields (model, enabledPlugins, cortexAgentConnectionName, theme) out of the versioned dotfiles base; generate them into ~/.config/borg/*.local.json overlay templates, created once and never overwritten

## context

Settings files for Claude Code and Cortex mix stable cross-machine config (permissions) with machine-specific or user-preference fields. Including the latter in the dotfiles base would either hardcode wrong values or require per-machine branches in dotfiles.

## reasoning

Separating concerns means the dotfiles base is truly portable and the local overlay holds only what must vary. The once-and-never-overwrite guard (if [[ ! -f ]]) ensures a developer's customizations survive repeated borg setup runs.
