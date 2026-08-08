---
id: 20260708-skill-distillation-independent-verification
date: '2026-07-08'
project: borg-collective
domain: code-quality
tags:
- skill-distillation
- verification
- grep
- blind-review
- load-bearing-config
alternatives: []
applies_to: []
confidence: 0.9
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260708-1940-orchestrator
created_at: '2026-07-08 19:41:01.400101+00:00'
updated_at: '2026-07-08 19:41:01.400102+00:00'
---

# 20260708-skill-distillation-independent-verification

## decision

Skill distillation must pass both an independent grep gate (literal string preservation list) and a blind operational review by a separate model before the distilled version is swapped live.

## context

Distilling research SKILL.md from 1001→550 lines. Self-check alone was insufficient — blind Sonnet review caught 6 dropped clauses the self-check missed.

## reasoning

Skills are behavioral configuration, not documentation. A dropped clause silently changes agent behavior in ways that may not surface until a production run. Two independent verification passes (mechanical grep + semantic operational review) catch orthogonal failure modes.
