---
id: 20260504-skill-extensions-hook-protocol
date: '2026-06-16'
project: borg-collective
domain: architecture
tags:
- claude-code
- skills
- extensibility
- hooks
- borg-plan
- borg-assimilate
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260616-0347-orchestrator
created_at: '2026-06-16 10:27:02.298437+00:00'
updated_at: '2026-06-16 10:27:02.298437+00:00'
---

# 20260504-skill-extensions-hook-protocol

## decision

Implement local context injection via a hook-protocol (load points embedded in upstream SKILL.md files) rather than wrapper or scaffolder patterns. Extensions live in per-machine and per-project layered scopes under `~/.config/borg/extensions/skill-extensions/`.

## context

borg-plan and borg-assimilate needed to absorb local context (e.g., JIRA ticket data) without forking upstream skills, which would create maintenance burden when upstream skills evolve.

## reasoning

Hook protocol keeps upstream SKILL.md files as the single source of truth while allowing local markdown files to inject context at well-defined load points. Wrapper pattern would duplicate logic; scaffolder pattern was overkill for what is essentially a content-injection problem.
