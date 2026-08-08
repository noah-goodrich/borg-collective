---
id: obs-20260616-terminal-transition-split-brain
session_date: '2026-06-16'
project: cairn
tool: claude-code
tags:
- locking
- error-handling
- outbox
- filesystem
- correctness
category: error_encountered
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260616-0914-cairn
superseded_by: null
created_at: '2026-06-16 10:27:03.292894+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260616-terminal-transition-split-brain

## content

mark_dead_letter originally caught only FileNotFoundError on the pending/ unlink. Any other OSError (permissions, I/O error, etc.) left the entry present in BOTH pending/ and dead-letter/ simultaneously, with the claim-lock still held. This split-brain state means the entry is both 'being processed' and 'failed' — subsequent drain runs would skip it (lock held) but it would never be reclaimed.

## resolution

Move lock release into a finally block as the last step of all three terminal transitions. This ensures: (1) lock is always released regardless of which step raises, (2) lock is released last so the file operation's success/failure determines the entry's canonical location before the lock becomes reclaimable.
