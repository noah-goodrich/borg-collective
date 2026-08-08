---
id: 20260616-sync-plugin-script
date: '2026-06-16'
project: borg-collective
domain: infrastructure
tags:
- plugin
- distribution
- sync
- drift-prevention
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260616-0347-orchestrator
created_at: '2026-06-16 10:27:02.502937+00:00'
updated_at: '2026-06-16 10:27:02.502938+00:00'
---

# 20260616-sync-plugin-script

## decision

Add `scripts/sync-plugin.sh` to mechanically sync skills from the source repo into the plugin distribution, replacing manual hand-copy.

## context

SKILL.md files in `claude-plugins` were drifting from their canonical versions in `borg-collective`. The directives-02-06 branch had stale copies discovered during this session.

## reasoning

Hand-copy is a human process that will always drift under time pressure. A script makes the correct action the easy action and makes drift visible (the script either succeeds or shows a diff).
