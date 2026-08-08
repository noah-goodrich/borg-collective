---
id: 20260506-borg-link-agent-invocable
date: '2026-06-11'
project: borg-collective
domain: architecture
tags:
- borg-collective
- agent-invocation
- skill-design
- permissions
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 22:41:19.409444+00:00'
updated_at: '2026-06-11 22:41:19.409444+00:00'
---

# 20260506-borg-link-agent-invocable

## decision

Removed `disable-model-invocation: true` from `borg-link-up` skill, making it agent-invocable

## context

borg-link-up was previously restricted to human invocation only; v0.7.13 release included enabling agent invocation

## reasoning

Skill is safe enough for agent use; removing the restriction enables automation workflows that need to invoke borg-link-up as part of larger agent-driven operations
