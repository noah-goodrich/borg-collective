---
id: obs-20260708-workflow-agent-silent-model-inheritance
session_date: '2026-07-08'
project: borg-collective
tool: claude-code
tags:
- workflow
- agent
- model-routing
- cost
- fable-5
- silent-behavior
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260708-1940-orchestrator
superseded_by: null
created_at: '2026-07-08 19:41:01.405415+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260708-workflow-agent-silent-model-inheritance

## content

Workflow agent() calls silently inherit the session's default model. When the session default is Fable 5 (the highest-cost tier at $10/$50), every agent() call in every workflow script runs on Fable 5 unless an explicit model: parameter is passed. With ~40 workflow agents per session, this silently consumed the session and weekly usage limits multiple times with no warning.

## resolution

Two mitigations applied: (1) changed ~/.claude/settings.json default to claude-opus-4-8, (2) added a rule to ROUTING.md requiring explicit model: on every agent() call. The CLAUDE.md workflow rule was drafted but not yet applied — must be applied next session via update-config skill.
