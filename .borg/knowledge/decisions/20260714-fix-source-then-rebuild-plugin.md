---
id: 20260714-fix-source-then-rebuild-plugin
date: '2026-07-14'
project: borg-collective
domain: infrastructure
tags:
- claude-plugins
- build-pipeline
- hooks
- borg-link-down
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260714-1733-borg-collective
created_at: '2026-07-14 17:34:17.049386+00:00'
updated_at: '2026-07-14 17:34:17.049388+00:00'
---

# 20260714-fix-source-then-rebuild-plugin

## decision

Always fix the root-cause bug in borg-collective's source hook (hooks/borg-link-down.sh), then propagate to claude-plugins via scripts/build-plugin.sh — never patch the plugin repo directly.

## context

The JSON-assembly bug manifested in claude-plugins CI, but the canonical source lives in borg-collective. scripts/build-plugin.sh does not sync test files, only hook sources.

## reasoning

Patching the plugin repo directly would be immediately overwritten by the next build script run, creating a silent regression. Single source of truth in borg-collective is the established convention.
