---
id: 20260415-machine-local-overlay-for-volatile-settings
date: '2026-06-11'
project: borg-collective
domain: architecture
tags:
- dotfiles
- settings
- machine-local
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
created_at: '2026-06-11 22:41:19.238500+00:00'
updated_at: '2026-06-11 22:41:19.238501+00:00'
---

# 20260415-machine-local-overlay-for-volatile-settings

## decision

Extract machine-specific fields (model, enabledPlugins) into a machine-local overlay file (~/.config/borg/claude-settings.local.json) rather than the versioned base

## context

Some settings fields like active model and enabled plugins are legitimately machine-specific and should not be overwritten by the shared dotfiles base

## reasoning

Including these in the versioned base would cause borg setup to silently overwrite plugin configuration on every run. Generating a template overlay on first run surfaces this boundary explicitly to the user.
