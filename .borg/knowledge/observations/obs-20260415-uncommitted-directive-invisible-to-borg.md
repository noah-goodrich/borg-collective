---
id: obs-20260415-uncommitted-directive-invisible-to-borg
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- git
- borg
- directives
- workflow
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.232456+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260415-uncommitted-directive-invisible-to-borg

## content

docs/plans/directives/2026-04-14-portfolio-mvp-pivot.md was created but left untracked/uncommitted at session end. borg link history (which presumably operates on git history) will not surface this directive until it is committed, making the strategic decision effectively invisible to future borg queries.

## resolution

Commit the file with a ship: prefix commit message to bring it into git history and make it discoverable via borg link.
