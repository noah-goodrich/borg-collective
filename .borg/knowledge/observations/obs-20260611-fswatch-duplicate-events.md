---
id: obs-20260611-fswatch-duplicate-events
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- fswatch
- events
- deduplication
- borg-notifyd
category: domain_knowledge
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.304941+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-fswatch-duplicate-events

## content

fswatch can deliver multiple events for a single file write (e.g., one for the write and one for metadata update). A naive notification daemon that fires on every event would produce duplicate popups per state transition.

## resolution

borg-notifyd maintains a per-project previous-state variable and only fires a notification when the newly-read state value differs from the stored previous value.
