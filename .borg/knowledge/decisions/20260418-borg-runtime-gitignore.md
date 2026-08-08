---
id: 20260418-borg-runtime-gitignore
date: '2026-06-11'
project: borg-collective
domain: infrastructure
tags:
- git
- gitignore
- borg
- runtime-state
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 20:39:25.044239+00:00'
updated_at: '2026-06-11 20:39:25.044239+00:00'
---

# 20260418-borg-runtime-gitignore

## decision

Add .borg/ to .gitignore alongside existing runtime exclusions (registry.json, .borg-project)

## context

.borg/ is a runtime state directory generated during borg operations; it was not previously excluded despite being analogous to already-ignored files

## reasoning

Runtime state should never be committed; treating .borg/ consistently with other excluded runtime artifacts prevents accidental repo pollution
