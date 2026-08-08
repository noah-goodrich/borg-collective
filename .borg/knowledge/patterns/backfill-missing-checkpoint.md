---
id: backfill-missing-checkpoint
project: borg-collective
domain: session-management
tags:
- checkpoint
- backfill
- borg-state
- session-hygiene
preconditions: []
steps:
- Locate the session's context artifacts (handoff notes, PR descriptions, commit messages)
  that describe what the missing checkpoint should contain
- Reconstruct the checkpoint file at the correct path (.borg/checkpoints/YYYY-MM-DD-HHMM.md)
  using that context
- Use the original session's timestamp in the filename, not the current date
- Commit the backfilled checkpoint to the borg-state branch (not main directly)
- Note in the commit message that this is a backfill, including the original session
  date
pitfalls:
- Do not use today's date for the filename — the checkpoint represents a past session
  and must be timestamped accordingly for chronological ordering to work
- Backfilled checkpoints should be committed to the borg-state branch along with any
  other untracked state files, not as a standalone commit to main
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.453580+00:00'
updated_at: '2026-06-11 22:41:19.453580+00:00'
---

# backfill-missing-checkpoint

## description

Reconstruct and commit a checkpoint that was described in session context but never written to disk
