---
id: 20260616-borg-plan-promote-hook-type
date: '2026-06-16'
project: borg-collective
domain: architecture
tags:
- claude-code
- hooks
- pretooluse
- plan-mode
- borg-collective
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260616-0347-orchestrator
created_at: '2026-06-16 10:27:02.386722+00:00'
updated_at: '2026-06-16 10:27:02.386723+00:00'
---

# 20260616-borg-plan-promote-hook-type

## decision

Implemented auto-plan-promote as a PreToolUse hook (Edit/Write/NotebookEdit) rather than a PostToolUse or standalone command

## context

Need to capture in-session ExitPlanMode plan to docs/plans/PROJECT_PLAN.md before any file modifications occur

## reasoning

PreToolUse fires before the first destructive action, guaranteeing the plan snapshot is written before edits begin; PostToolUse would be too late if the first edit is the plan file itself; standalone command requires manual invocation and could be forgotten
