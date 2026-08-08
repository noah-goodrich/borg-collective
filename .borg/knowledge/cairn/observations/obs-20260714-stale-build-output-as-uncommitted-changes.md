---
id: obs-20260714-stale-build-output-as-uncommitted-changes
session_date: '2026-07-14'
project: cairn
tool: claude-code
tags:
- claude-plugins
- build-artifacts
- git
- uncommitted-work
category: gotcha
files_involved: []
confidence: 0.8
source_model: null
source_session: 20260714-0405-cairn
superseded_by: null
created_at: '2026-07-14 04:06:54.534668+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260714-stale-build-output-as-uncommitted-changes

## content

claude-plugins had uncommitted changes that appeared to be 'foreign' precious work from another session. Investigation revealed they were stale `build-plugin.sh` output (build artifacts that should not be committed), not hand-written code. This is a non-obvious failure mode: build artifacts in a repo without a `.gitignore` covering them look identical to uncommitted feature work.

## resolution

Stashed as a safety net, then rebuilt from borg-collective `main`. The stash can be dropped. Ensure build output paths are covered by `.gitignore` in claude-plugins to prevent recurrence.
