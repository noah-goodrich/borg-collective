---
id: obs-20260611-inverted-hook-names
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- hooks
- lifecycle
- naming
- borg-link-up
- borg-link-down
- SessionStart
- Stop
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 20:39:25.138271+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-inverted-hook-names

## content

borg-link-up.sh and borg-link-down.sh were created with inverted semantics: link-up was registered as the SessionStart hook (should be download/pull) and link-down was registered as the Stop hook (should be upload/push). The intuitive mental model is link-up = upload to collective (Stop/flush), link-down = download from collective (SessionStart/hydrate). The implementation had these backwards throughout — hook files, skill dirs, settings.json, docs, tests, and help text all reflect the inversion.

## resolution

Full inversion swap required across ~15 files plus live environment copies. Must be done atomically in one turn using the two-step .swap rename sequence. See Next Session plan in session artifact for the exhaustive file list.
