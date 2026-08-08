---
id: 20260611-borg-plan-promote-pretools-hook
date: '2026-06-11'
project: borg-collective
domain: architecture
tags:
- hooks
- claude-code
- plan-mode
- automation
- idempotent
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 22:41:19.436211+00:00'
updated_at: '2026-06-11 22:41:19.436211+00:00'
---

# 20260611-borg-plan-promote-pretools-hook

## decision

Implement auto-plan-promote as a PreToolUse hook (Edit/Write/NotebookEdit) rather than a manual command or post-session step

## context

Need to persist the in-session ExitPlanMode plan to docs/plans/PROJECT_PLAN.md before the first edit so plans survive session boundaries

## reasoning

PreToolUse fires before the first destructive action (edit/write), giving exactly one natural capture point. Idempotent design (always exits 0, skips if plan already written) prevents double-writes on subsequent edits. Project-mode-only guard prevents spurious fires.
