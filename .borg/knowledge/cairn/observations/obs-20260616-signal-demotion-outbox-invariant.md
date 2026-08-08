---
id: obs-20260616-signal-demotion-outbox-invariant
session_date: '2026-06-16'
project: cairn
tool: claude-code
tags:
- cairn
- signal
- state-machine
- outbox
- zero-loss
category: domain_knowledge
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260616-0914-cairn
superseded_by: null
created_at: '2026-06-16 10:27:03.271907+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260616-signal-demotion-outbox-invariant

## content

The four-state signal classifier (not_installed/warming/live/down) encodes a zero-loss invariant: demotion is HARD-BLOCKED while the outbox queue is non-empty. This is the load-bearing rule that connects the signal state machine to the outbox — they are not independent.

## resolution

When implementing _signal.py and outbox.py, the demotion check must query the outbox pending/ directory count before allowing any state transition downward.
