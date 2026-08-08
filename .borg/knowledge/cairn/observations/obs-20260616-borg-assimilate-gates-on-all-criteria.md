---
id: obs-20260616-borg-assimilate-gates-on-all-criteria
session_date: '2026-06-16'
project: cairn
tool: claude-code
tags:
- borg-assimilate
- workflow
- gates
- acceptance-criteria
category: tool_behavior
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260616-0914-cairn
superseded_by: null
created_at: '2026-06-16 10:27:03.294202+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260616-borg-assimilate-gates-on-all-criteria

## content

The borg-assimilate workflow gates Collective Review on ALL acceptance criteria being met. Running it mid-flight (when only 2 of 7 slices are building blocks toward the criteria) produces 0/7 met and no review — not a failure of the code, just a workflow timing issue.

## resolution

Do not run borg-assimilate until all acceptance criteria for the current scope are fully implemented and verified. Use it as a final gate, not a progress check.
