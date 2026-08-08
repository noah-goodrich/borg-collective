---
id: obs-20260616-inverted-naming-caught-precommit
session_date: '2026-06-16'
project: borg-collective
tool: claude-code
tags:
- naming
- session-lifecycle
- hooks
- git-hygiene
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.212547+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260616-inverted-naming-caught-precommit

## content

When renaming hooks to reflect data-flow direction (link-up/link-down), the semantics were implemented in the wrong direction — the 'upload to collective' hook was named link-down and wired to SessionStart, while 'download from collective' was named link-up and wired to Stop. This was the opposite of the intended convention (down=pull from remote at start, up=push to remote on demand). The error was caught by reviewing the session summary before committing.

## resolution

Do not commit until a full swap pass is done using intermediate .tmpswap names. The session notes explicitly block commit until the swap is complete to avoid polluting git history with an inverted-then-re-inverted rename sequence.
