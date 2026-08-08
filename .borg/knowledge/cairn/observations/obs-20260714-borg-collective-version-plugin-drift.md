---
id: obs-20260714-borg-collective-version-plugin-drift
session_date: '2026-07-14'
project: cairn
tool: claude-code
tags:
- borg-collective
- claude-plugins
- version
- drift
- release
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260714-0405-cairn
superseded_by: null
created_at: '2026-07-14 04:06:54.534133+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260714-borg-collective-version-plugin-drift

## content

borg-collective `VERSION` was stuck at 0.8.6 while claude-plugins had already shipped plugin 0.8.7, creating a version mismatch between the plugin artifact and the source repo's declared version. This was discovered when reconciling the claude-plugins uncommitted 'foreign' work (which turned out to be stale build output, not precious changes).

## resolution

Bumped `VERSION` to 0.8.8 in borg-collective #76, then rebuilt the plugin at 0.8.8 in claude-plugins PR #33. Version and artifact are now aligned.
