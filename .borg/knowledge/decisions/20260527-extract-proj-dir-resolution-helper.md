---
id: 20260527-extract-proj-dir-resolution-helper
date: '2026-06-11'
project: borg-collective
domain: code-quality
tags:
- bash
- refactoring
- shell-helpers
- dry
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 22:41:19.493281+00:00'
updated_at: '2026-06-11 22:41:19.493282+00:00'
---

# 20260527-extract-proj-dir-resolution-helper

## decision

Extract repeated PROJ_DIR resolution block (appeared 3 identical times across hooks) into a dedicated _borg_resolve_proj_dir helper, replacing $(dirname ...) subprocess calls with ${sf%/*} parameter expansion.

## context

Code smell flagged during /simplify review. Three hooks contained copy-pasted PROJ_DIR resolution logic.

## reasoning

Single source of truth for a non-trivial resolution path prevents divergence. Parameter expansion ${sf%/*} avoids a subprocess fork for every hook invocation, which matters in hook-heavy workflows.
