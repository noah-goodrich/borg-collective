---
id: obs-20260423-dockerenv-guard-double-fire-risk
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- devcontainer
- docker
- notifications
- osascript
- guard
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 20:39:25.114956+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260423-dockerenv-guard-double-fire-risk

## content

If a notification script (notify.sh) does not check for /.dockerenv before attempting osascript, both the host-side borg-notifyd daemon AND the in-container script can trigger on the same state transition, causing duplicate popups. The /.dockerenv file is present in all Docker containers and is the canonical runtime check.

## resolution

Add a guard at the top of any host-notification script: `[ -f /.dockerenv ] && exit 0`. This makes the in-container invocation a silent no-op while leaving host-side invocations unaffected.
