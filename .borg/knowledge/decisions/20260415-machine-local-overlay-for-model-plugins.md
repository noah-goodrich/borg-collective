---
id: 20260415-machine-local-overlay-for-model-plugins
date: '2026-06-11'
project: borg-collective
domain: dotfiles
tags:
- dotfiles
- claude
- settings-management
- machine-local
- overlay
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 20:39:25.005449+00:00'
updated_at: '2026-06-11 20:39:25.005450+00:00'
---

# 20260415-machine-local-overlay-for-model-plugins

## decision

Generate a machine-local overlay template (~/.config/borg/claude-settings.local.json) for model and enabledPlugins rather than managing them in the versioned base

## context

model selection and enabled plugins are machine-specific concerns that should not be overwritten by borg setup

## reasoning

Putting machine-specific keys in the versioned base means borg setup would overwrite them on every run. A generated local template surfaces the right keys for users to fill in while keeping them out of source control.
