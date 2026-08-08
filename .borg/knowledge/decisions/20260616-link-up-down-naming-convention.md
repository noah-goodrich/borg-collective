---
id: 20260616-link-up-down-naming-convention
date: '2026-06-16'
project: borg-collective
domain: architecture
tags:
- session-lifecycle
- naming
- hooks
- mental-model
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260616-0347-orchestrator
created_at: '2026-06-16 10:27:02.209973+00:00'
updated_at: '2026-06-16 10:27:02.209974+00:00'
---

# 20260616-link-up-down-naming-convention

## decision

Established semantic convention: borg-link-down = SessionStart hook (downloads FROM collective INTO session); borg-link-up = manual skill (uploads session state TO collective). Analogous to git pull/push or rsync down/up.

## context

The lifecycle hooks needed renaming from the generic borg-start/borg-stop to reflect the data-flow direction. Initial implementation got the direction inverted — link-up was wired to SessionStart and link-down to Stop — discovered at end of session before commit.

## reasoning

The network/sync metaphor (link-up = upload to remote, link-down = download from remote) makes the data flow self-documenting. 'Down' at session start matches the intuition of 'pulling down context from the collective'. Catching this before commit avoids permanent noise in git history.
