---
id: 20260611-bash-guard-layer-1.5-preapproval
date: '2026-06-11'
project: borg-collective
domain: code-quality
tags:
- bash-guard
- borg-link
- permission-prompts
- for-loops
- shell-patterns
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 22:41:19.419051+00:00'
updated_at: '2026-06-11 22:41:19.419052+00:00'
---

# 20260611-bash-guard-layer-1.5-preapproval

## decision

Add Layer 1.5 pre-approval in bash-guard.sh for specific for-loop patterns over known safe path globs (*/docs/plans/* and */.borg/checkpoints/*) rather than broadly allowing all for-loops or rewriting borg-link to avoid them.

## context

borg-link was generating 'Unhandled node type: string' prompts during execution because bash-guard's AST parser didn't handle for-loop iteration over glob patterns in those specific directories.

## reasoning

Targeted pre-approval preserves security posture of bash-guard while eliminating noisy prompts for patterns that are structurally safe (read-only iteration over known repo subdirectories). Broad for-loop allowance would erode the guard's value.
