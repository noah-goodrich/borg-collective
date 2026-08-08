---
id: 20260417-borg-dir-gitignore
date: '2026-06-11'
project: borg-collective
domain: code-quality
tags:
- git
- gitignore
- borg
- runtime-artifacts
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 20:39:25.035266+00:00'
updated_at: '2026-06-11 20:39:25.035267+00:00'
---

# 20260417-borg-dir-gitignore

## decision

Add `.borg/` to `.gitignore` to exclude runtime borg state from version control

## context

The `.borg/` directory holds session/registry runtime artifacts that are generated at runtime and should not be committed.

## reasoning

Prevents noise and potentially sensitive session state from leaking into the repo history. Runtime artifacts are not source artifacts.
