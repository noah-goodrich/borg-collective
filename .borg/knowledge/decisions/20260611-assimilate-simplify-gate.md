---
id: 20260611-assimilate-simplify-gate
date: '2026-06-11'
project: borg-collective
domain: code-quality
tags:
- assimilate
- simplify
- gating
- workflow
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 20:39:24.965466+00:00'
updated_at: '2026-06-11 20:39:24.965467+00:00'
---

# 20260611-assimilate-simplify-gate

## decision

Add a Step 0 gate to borg-assimilate SKILL.md requiring `/simplify` confirmation before shipping

## context

Assimilated code was being shipped without a simplification pass, accumulating complexity debt.

## reasoning

Gating at the skill level makes the requirement explicit and machine-checkable at the point of action, rather than relying on developer memory or PR review.
