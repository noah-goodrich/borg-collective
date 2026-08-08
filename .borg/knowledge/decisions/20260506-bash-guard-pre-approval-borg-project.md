---
id: 20260506-bash-guard-pre-approval-borg-project
date: '2026-06-11'
project: borg-collective
domain: infrastructure
tags:
- borg-collective
- bash-guard
- permissions
- ux
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 22:41:19.410031+00:00'
updated_at: '2026-06-11 22:41:19.410032+00:00'
---

# 20260506-bash-guard-pre-approval-borg-project

## decision

Added bash-guard pre-approval for `.borg-project` marker walks to eliminate 2 permission prompts on every `/borg-link` invocation

## context

Every `/borg-link` call was triggering 2 redundant permission prompts for directory walks that look for `.borg-project` marker files

## reasoning

These walks are safe, deterministic, and non-destructive; pre-approving them removes friction without introducing security risk
