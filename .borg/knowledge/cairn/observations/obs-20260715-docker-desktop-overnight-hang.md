---
id: obs-20260715-docker-desktop-overnight-hang
session_date: '2026-07-15'
project: cairn
tool: docker
tags:
- docker-desktop
- macos
- reliability
- daemon
category: tool_behavior
files_involved: []
confidence: 0.9
source_model: null
source_session: null
superseded_by: null
created_at: '2026-07-15 15:41:50.300566+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260715-docker-desktop-overnight-hang

## content

Docker Desktop hung the host machine overnight (this is a recurring issue, also noted in the 2026-07-14 handover). A quit/reopen restart did not stabilize it immediately; the daemon was healthy again by morning. This blocked the deploy until the environment recovered.

## resolution

Plan deploys for when the machine has been recently restarted or the daemon is confirmed healthy. If Docker Desktop hangs, allow a full restart cycle rather than expecting a quick recovery from quit/reopen.
