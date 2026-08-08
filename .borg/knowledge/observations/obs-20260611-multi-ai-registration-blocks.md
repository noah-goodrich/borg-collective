---
id: obs-20260611-multi-ai-registration-blocks
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- hooks
- claude
- coco
- registration
- cmd-setup
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 20:39:25.162006+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-multi-ai-registration-blocks

## content

`borg.zsh cmd_setup` registers each hook multiple times — once for Claude and once for CoCo (Cortex Copilot), giving 4 registration calls for a Start+Stop hook pair. During the inversion swap, all 4 had to be updated. Missing any one registration block means the wrong hook fires for one AI tool while the other is correct — a subtle, hard-to-debug divergence.

## resolution

When editing hook registrations in cmd_setup, grep for both the hook filename and the tool name to find all registration blocks before editing.
