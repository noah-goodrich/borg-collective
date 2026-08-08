---
id: obs-20260616-edit-direction-reversal
session_date: '2026-06-16'
project: borg-collective
tool: claude-code
tags:
- claude-plugins
- borg-collective
- documentation
- edit-direction
- source-of-truth
category: error_encountered
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.409847+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260616-edit-direction-reversal

## content

A directive doc in claude-plugins (2026-05-27-borg-cairn-coordination.md) had the edit direction backwards — it described changes flowing from claude-plugins into borg-collective, which inverts the established canonical model.

## resolution

Corrected the doc to reflect the correct direction (borg-collective → claude-plugins) and pushed directly to claude-plugins main. Updated the corresponding handoff doc in borg-collective to mark the question resolved.
