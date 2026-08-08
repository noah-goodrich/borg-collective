---
id: obs-20260527-placeholder-checkpoint-deletion
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- checkpoints
- borg-state
- dispatch-orchestrator
- placeholder
category: domain_knowledge
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.447633+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260527-placeholder-checkpoint-deletion

## content

The Dispatch orchestrator writes placeholder checkpoint files (e.g., `2026-05-26-2203.md`) when it initiates a session. These placeholders are superseded by the real checkpoint and must be deleted in the same commit that adds the real file — otherwise both exist in history and create ambiguity about which is authoritative.

## resolution

Include the placeholder deletion explicitly in the borg-state PR's file list. The superseding checkpoint should note which file it replaces.
