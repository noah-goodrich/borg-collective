---
id: obs-20260527-edit-direction-inversion-claude-plugins
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- claude-plugins
- source-of-truth
- edit-direction
- directive-doc
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.453913+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260527-edit-direction-inversion-claude-plugins

## content

The directive doc in claude-plugins/docs/plans/directives/ had the edit direction backwards — it implied edits should flow from claude-plugins into borg-collective, when the correct direction is the inverse. This was a documentation error that could cause a future session to make changes in the wrong repo and then wonder why borg-collective state diverges.

## resolution

Corrected the directive doc and pushed to claude-plugins main. The canonical decision (borg-collective → claude-plugins) is now also recorded in a borg-collective handoff doc.
