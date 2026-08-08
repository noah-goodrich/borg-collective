---
id: obs-20260428-borg-stop-hook-is-session-end
session_date: '2026-06-11'
project: cairn
tool: cursor
tags:
- borg-collective
- hooks
- claude-code
- session-lifecycle
category: domain_knowledge
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260611-1925-cairn
superseded_by: null
created_at: '2026-06-11 20:31:17.999742+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260428-borg-stop-hook-is-session-end

## content

In the borg-collective hook architecture, `borg-link-up.sh` is the Stop hook (fires on session end) and `borg-link-down.sh` is the Start hook (fires on session start). The naming is counterintuitive — 'up' refers to the borg link state after the hook runs, not the session state.

## resolution

When adding session-end instrumentation (like auto-recording to cairn), target borg-link-up.sh. When adding session-start instrumentation (like cairn-hits.log), target borg-link-down.sh.
