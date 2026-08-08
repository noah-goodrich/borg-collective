---
id: obs-20260611-fswatch-deleted-project-pruning
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- fswatch
- borg-notifyd
- state-tracking
- pruning
category: domain_knowledge
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 20:39:25.102081+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-fswatch-deleted-project-pruning

## content

fswatch emits events for deleted files/directories. Without explicit pruning of the per-project state tracking dictionary in borg-notifyd, deleted projects accumulate stale entries, causing the daemon to attempt to read nonexistent state files on each subsequent fswatch event and potentially re-firing stale notifications.

## resolution

borg-notifyd checks if the watched path no longer exists on each event and removes the corresponding entry from the state dictionary.
