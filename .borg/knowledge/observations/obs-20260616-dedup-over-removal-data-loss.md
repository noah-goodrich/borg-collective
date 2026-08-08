---
id: obs-20260616-dedup-over-removal-data-loss
session_date: '2026-06-16'
project: borg-collective
tool: claude-code
tags:
- settings.json
- deduplication
- data-loss
- hooks
- borg-setup
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.528043+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260616-dedup-over-removal-data-loss

## content

De-dup logic that removes ALL instances of a duplicate key and re-inserts once will silently delete user-defined entries if the insertion logic has an off-by-one or wrong-context bug. In this case, `session-log.sh` was deleted from the user's settings by the over-aggressive de-dup in `borg setup`.

## resolution

Fixed in #45: de-dup now removes exactly N-1 copies, keeping one survivor in place. Regression test added to 248-test bats suite. Always restore deleted user hooks manually after diagnosing — they are not recoverable from git.
