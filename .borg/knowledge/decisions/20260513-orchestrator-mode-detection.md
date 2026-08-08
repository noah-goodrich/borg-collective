---
id: 20260513-orchestrator-mode-detection
date: '2026-06-16'
project: borg-collective
domain: architecture
tags:
- shell
- orchestrator-mode
- path-matching
- borg-collective
alternatives: []
applies_to: []
confidence: 0.9
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260616-0347-orchestrator
created_at: '2026-06-16 10:27:02.377089+00:00'
updated_at: '2026-06-16 10:27:02.377089+00:00'
---

# 20260513-orchestrator-mode-detection

## decision

Detect orchestrator mode via exact-match of cwd against BORG_ORCHESTRATOR_ROOT with trailing-slash tolerance, not prefix/substring matching

## context

Need to classify whether a Claude session is operating at the workspace root (orchestrator) or inside a specific project subdirectory (project mode).

## reasoning

Prefix matching would incorrectly classify ~/dev/borg-collective as orchestrator mode when BORG_ORCHESTRATOR_ROOT=~/dev — the smoke test confirmed this was the core bug case. Exact match is unambiguous. Trailing-slash tolerance handles the common ~/dev vs ~/dev/ variation in how users set env vars.
