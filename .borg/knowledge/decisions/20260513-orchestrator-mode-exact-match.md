---
id: 20260513-orchestrator-mode-exact-match
date: '2026-06-11'
project: borg-collective
domain: architecture
tags:
- shell
- borg-collective
- orchestrator-mode
- session-classification
- path-matching
alternatives: []
applies_to: []
confidence: 0.9
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 22:41:19.427747+00:00'
updated_at: '2026-06-11 22:41:19.427748+00:00'
---

# 20260513-orchestrator-mode-exact-match

## decision

Classify a session as orchestrator-mode only when cwd exactly equals BORG_ORCHESTRATOR_ROOT (trailing-slash tolerant), not when cwd is a subdirectory of it

## context

The bug case was: cd ~/dev/borg-collective triggered orchestrator mode because ~/dev/borg-collective is under ~/dev. This caused the borg-collective project itself to never get proper project-mode session handling.

## reasoning

Exact-match (with trailing-slash normalization) is the minimal, unambiguous rule. Any subdirectory of BORG_ORCHESTRATOR_ROOT is a project and should get project-mode. Only sitting directly at the workspace root warrants the cross-project overview.
