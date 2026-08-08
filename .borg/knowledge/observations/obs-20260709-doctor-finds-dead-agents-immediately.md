---
id: obs-20260709-doctor-finds-dead-agents-immediately
session_date: '2026-07-09'
project: borg-collective
tool: claude-code
tags:
- borg-doctor
- launchd
- agent-health
- cross-machine
category: pattern_discovered
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260709-1659-borg-collective
superseded_by: null
created_at: '2026-07-09 17:01:17.389521+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260709-doctor-finds-dead-agents-immediately

## content

borg doctor found two dead agents (notifyd and cortex-wake, both at exit 127) within seconds of being created. These agents had been silently dead for an unknown period. The pattern of silent launchd failure is likely to recur on the work machine after sync.

## resolution

Run borg doctor immediately after ./install.sh on any new machine sync. The work machine likely has the same two dead agents if claude ever moved to ~/.local/bin via claude update or migrate-installer.
