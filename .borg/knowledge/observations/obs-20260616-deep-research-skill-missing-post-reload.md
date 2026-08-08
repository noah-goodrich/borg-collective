---
id: obs-20260616-deep-research-skill-missing-post-reload
session_date: '2026-06-16'
project: borg-collective
tool: claude-code
tags:
- claude-code
- plugins
- skills
- reload-plugins
category: tool_behavior
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.389443+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260616-deep-research-skill-missing-post-reload

## content

/deep-research skill was expected to be available after /reload-plugins was run but was not present. No error was thrown — the skill was simply absent from the loaded plugin set.

## resolution

No action taken in session — flagged only. Investigate whether /deep-research requires a separate installation step or whether its plugin manifest is missing/malformed. Check plugin directory for the skill definition file.
