---
id: cairn-outbox-terminal-transition-lock-leak-2026-06-09
session_date: '2026-06-10'
project: cairn
tool: claude-code
tags:
- outbox
- filesystem
- locking
- bug
- durability
category: error_encountered
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260610-1630-cairn
superseded_by: null
created_at: '2026-06-10 16:50:37.422748+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# cairn-outbox-terminal-transition-lock-leak-2026-06-09

## content

In the outbox implementation, mark_dead_letter() only caught FileNotFoundError on the pending unlink. Any other OSError (e.g., permissions, ENOSPC) left a dangling lock file with the entry in both pending/ and dead-letter/ simultaneously — a split-brain state that blocks all future drain attempts for that entry.

## resolution

Release the lock in a finally block across all three terminal transitions (mark_done, mark_dead_letter, mark_transient_fail). The lock file must be the last thing cleaned up, after all other FS operations for that transition are complete.
