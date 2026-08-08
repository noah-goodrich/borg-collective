---
id: obs-20260423-post-write-hook-line-length
session_date: '2026-06-16'
project: borg-collective
tool: claude-code
tags:
- borg
- hooks
- linting
- checkpoints
category: tool_behavior
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.201770+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260423-post-write-hook-line-length

## content

The post-write hook checks for lines >120 characters in checkpoint files and flags violations. During this session it fired as a warning (not a blocking error), but the behavior may change if enforcement is tightened.

## resolution

Reflow checkpoint markdown to stay under 120 chars per line when writing, or at minimum reflow before the hook is promoted to error-level enforcement. The specific file flagged: .borg/checkpoints/2026-04-23-0233.md
