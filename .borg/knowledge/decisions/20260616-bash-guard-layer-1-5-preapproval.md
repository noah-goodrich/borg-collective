---
id: 20260616-bash-guard-layer-1-5-preapproval
date: '2026-06-16'
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
source_session: 20260616-0347-orchestrator
created_at: '2026-06-16 10:27:02.332039+00:00'
updated_at: '2026-06-16 10:27:02.332039+00:00'
---

# 20260616-bash-guard-layer-1-5-preapproval

## decision

Added pre-approval in bash-guard.sh Layer 1.5 for specific for-loop glob patterns (*/docs/plans/* and */.borg/checkpoints/*) rather than broadly allowing all for-loops

## context

borg-link was generating 'Unhandled node type: string' permission prompts during normal operation, blocking workflow

## reasoning

Targeted pre-approval of known-safe directory traversal patterns avoids over-permissioning while eliminating the prompt noise. Broad for-loop approval would weaken the guard's purpose.
