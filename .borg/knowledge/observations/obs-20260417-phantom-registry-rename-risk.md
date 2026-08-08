---
id: obs-20260417-phantom-registry-rename-risk
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- borg
- registry
- project-rename
- phantom-entries
- scan
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 20:39:25.036593+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260417-phantom-registry-rename-risk

## content

Project renames (e.g., `wallpaper-kit → reveal`, and potentially a subsequent rename to `ingle`) cause phantom registry entries in borg's project scanner. Subpaths like `.devcontainer/borg-hooks/` or `migrations/` inside a renamed project can be re-registered as if they were independent projects.

## resolution

The `cb3f166` commit introduced a scan fix for this class of bug. After any project rename, run `borg scan` and manually verify no subpaths of the renamed project appear as top-level registry entries. Smoke-test specifically against the new project name (e.g., `ingle`) to confirm the fix holds.
