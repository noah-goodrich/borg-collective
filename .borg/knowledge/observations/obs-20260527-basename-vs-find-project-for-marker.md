---
id: obs-20260527-basename-vs-find-project-for-marker
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- bash
- hooks
- project-resolution
- marker-files
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.494697+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260527-basename-vs-find-project-for-marker

## content

borg-notify.sh was using basename to resolve the project marker path. basename only strips directory components from a string — it does not walk the filesystem to find the actual project root. This caused incorrect marker paths when the hook was invoked from a subdirectory of the project.

## resolution

Replaced basename usage with _borg_find_project, which walks up the directory tree to locate the actual .borg marker. Any hook that needs the project root must use the dedicated resolver, not string manipulation on the current path.
