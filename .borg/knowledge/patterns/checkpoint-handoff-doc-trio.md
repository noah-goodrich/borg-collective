---
id: checkpoint-handoff-doc-trio
project: borg-collective
domain: infrastructure
tags:
- handoff
- borg-state
- checkpoints
- documentation
preconditions: []
steps:
- Identify each open thread that requires a human decision or a separate future action.
- Create `docs/plans/handoff/YYYY-MM-DD-<slug>.md` for each thread, scoped to exactly
  that one question or action.
- In the checkpoint's Blockers section, name each handoff doc explicitly.
- In the checkpoint's Next Session section, list the handoff docs as the first read
  step.
- When a thread is resolved, delete or archive its handoff doc so the directory only
  contains live items.
pitfalls:
- Writing a single combined handoff doc makes it impossible to delete it when only
  one thread is resolved.
- Handoff docs that are never deleted accumulate and lose signal — the directory should
  only contain actionable items.
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.446620+00:00'
updated_at: '2026-06-11 22:41:19.446621+00:00'
---

# checkpoint-handoff-doc-trio

## description

For any session that ends with open decisions or deferred work, produce one handoff doc per open thread (not one combined doc) so each can be resolved and deleted independently.
