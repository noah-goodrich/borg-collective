---
id: obs-20260611-borg-setup-gitignore-reinjection
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- borg-collective
- borg-setup
- gitignore
- install.sh
- idempotency
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.486488+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-borg-setup-gitignore-reinjection

## content

borg setup re-injects .borg/ into each project's .gitignore on every invocation because install.sh appends the line without first checking if it already exists. PR #29 fixed the repo's own .gitignore but left the root cause in install.sh untouched, so every subsequent borg setup run silently re-introduces the erroneous ignore rule.

## resolution

Fix install.sh to (a) check for existing .borg/ or .borg/state.json entries before appending, and (b) append only .borg/state.json rather than .borg/. The fix is scoped to Directive B implementation. Look around install.sh line 200+.
