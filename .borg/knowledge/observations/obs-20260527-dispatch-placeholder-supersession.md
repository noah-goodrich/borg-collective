---
id: obs-20260527-dispatch-placeholder-supersession
session_date: '2026-06-16'
project: borg-collective
tool: claude-code
tags:
- checkpoints
- dispatch
- orchestrator
- borg-state
category: pattern_discovered
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.399651+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260527-dispatch-placeholder-supersession

## content

The Dispatch orchestrator writes a placeholder checkpoint at session start (e.g., 2026-05-26-2203.md) which is superseded and deleted when the real checkpoint is written at session end. Both the new checkpoint and the deletion of the placeholder should be in the same commit to avoid a state where the placeholder appears to be the authoritative record.

## resolution

The supersession pattern is already followed — include the placeholder deletion in the same commit as the real checkpoint. Document the supersession relationship at the top of the real checkpoint file.
