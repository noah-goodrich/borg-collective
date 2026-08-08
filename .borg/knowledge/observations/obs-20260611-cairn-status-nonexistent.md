---
id: obs-20260611-cairn-status-nonexistent
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- cairn
- cli
- error-messaging
- debugging
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.522044+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-cairn-status-nonexistent

## content

`borg-link-up.sh` was emitting `cairn status` in its failure nudge, but `cairn status` is not a valid subcommand. The correct subcommand is `cairn health`. This caused operators debugging cairn write failures to immediately hit a second error, obscuring the root cause.

## resolution

PR #40 corrected the nudge to `cairn health`. When adding cairn diagnostic nudges, verify the subcommand exists in the installed version.
