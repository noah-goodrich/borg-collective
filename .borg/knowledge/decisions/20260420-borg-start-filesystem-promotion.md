---
id: 20260420-borg-start-filesystem-promotion
date: '2026-06-11'
project: borg-collective
domain: architecture
tags:
- borg
- lifecycle
- project-plan
- filesystem
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
created_at: '2026-06-11 20:39:25.081255+00:00'
updated_at: '2026-06-11 20:39:25.081256+00:00'
---

# 20260420-borg-start-filesystem-promotion

## decision

borg start is a pure filesystem promotion: directives/ → PROJECT_PLAN.md → assimilated/. One in-flight plan enforced by file existence check. No schema changes.

## context

Needed a formal lifecycle transition from backlog directive to active work item without overcomplicating the existing borg-assimilate contract.

## reasoning

PROJECT_PLAN.md as a singleton sentinel is simple, shell-scriptable, and git-visible. The assimilated side was already handled; start just needed the inverse. Avoiding schema changes kept the blast radius minimal.
