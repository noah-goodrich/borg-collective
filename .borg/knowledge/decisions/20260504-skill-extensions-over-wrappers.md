---
id: 20260504-skill-extensions-over-wrappers
date: '2026-06-11'
project: borg-collective
domain: architecture
tags:
- borg-collective
- extensibility
- plugin-protocol
- skills
- claude
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 22:41:19.391463+00:00'
updated_at: '2026-06-11 22:41:19.391464+00:00'
---

# 20260504-skill-extensions-over-wrappers

## decision

Implement context-specific behavior via a hook/load-point protocol embedded in SKILL.md files (skill-extensions/) rather than wrapper scripts or a scaffolder pattern.

## context

borg-plan and borg-assimilate needed to absorb local context (e.g., JIRA ticket data) without forking upstream skills. Three competing patterns were evaluated.

## reasoning

Load points in upstream SKILL.md files keep the core skills unforked and allow per-machine and per-project layering without requiring executable code or a separate scaffolding step. Markdown-only constraint keeps it simple and auditable in v1.
