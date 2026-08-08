---
id: obs-20260527-borg-notify-basename-vs-find-project
session_date: '2026-06-16'
project: borg-collective
tool: claude-code
tags:
- borg-collective
- hooks
- borg-notify
- marker-resolution
category: error_encountered
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.458628+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260527-borg-notify-basename-vs-find-project

## content

borg-notify.sh was using basename to resolve the project marker, which produces only the final directory component and breaks when projects are nested or share a common basename. The correct helper is _borg_find_project, which traverses upward to find the actual .borg marker.

## resolution

Replaced basename call with _borg_find_project in borg-notify.sh. Any hook that needs to locate a project root from within an arbitrary working directory should use _borg_find_project, not basename.
