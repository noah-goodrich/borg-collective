---
id: obs-20260609-osa-notify-inlined-for-fresh-install
session_date: '2026-06-16'
project: borg-collective
tool: claude-code
tags:
- hooks
- notify
- fresh-install
- osa
- plugin-self-containment
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.514177+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260609-osa-notify-inlined-for-fresh-install

## content

_borg_osa_notify was inlined directly into hooks/notify.sh (rather than sourced from lib/) to fix a fresh-install failure where lib/ isn't on the path yet when hooks first run. This creates a maintenance gotcha: the canonical definition in lib/borg-hooks.sh and the inlined copy in hooks/notify.sh can silently diverge.

## resolution

Treat hooks/notify.sh as the source-of-truth for _borg_osa_notify during the install phase. Any change to the function must be applied in both places until a proper bootstrap sourcing mechanism is in place. Add a comment in both files cross-referencing the other.
