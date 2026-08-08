---
id: 20260616-terminal-transition-lock-release-finally
date: '2026-06-16'
project: cairn
domain: code-quality
tags:
- locking
- error-handling
- filesystem
- outbox
- correctness
alternatives: []
applies_to: []
confidence: 0.9
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260616-0914-cairn
created_at: '2026-06-16 10:27:03.288326+00:00'
updated_at: '2026-06-16 10:27:03.288327+00:00'
---

# 20260616-terminal-transition-lock-release-finally

## decision

Release the claim-lock in a finally block as the last step of all three terminal transitions (mark_done, mark_dead_letter, mark_transient_fail)

## context

Code review found a real bug: mark_dead_letter caught only FileNotFoundError on the pending unlink, so any other OSError left a dangling lock with the entry present in both pending/ and dead-letter/ simultaneously

## reasoning

Lock release in finally ensures the lock is always released regardless of which step fails. Releasing last (after the move/rename) ensures atomicity: if the rename fails, the lock stays held and the entry remains claimable. If the rename succeeds but lock release fails (unlikely), the lease reclaim will eventually recover.
