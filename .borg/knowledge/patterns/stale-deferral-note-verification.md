---
id: stale-deferral-note-verification
project: borg-collective
domain: project-management
tags:
- planning
- status-hygiene
- deferred-debt
- reveal
preconditions: []
steps:
- Identify the deferral note and its stated blocking condition (e.g. 'queued behind
  Alembic work').
- Search git log or commit messages for evidence that the blocking condition was resolved
  (e.g. `git log --oneline --all | grep -i alembic`).
- If the blocker shipped, enumerate what work has happened since — tests passing,
  features added — to confirm the project is functionally Active.
- Update the plan document's status and add a 'What's actually shipped' subsection
  to document the current state.
- Verify no downstream directives or portfolio plans still reference the old blocked
  status.
pitfalls:
- Deferral notes are rarely cleaned up after the blocker resolves — they silently
  accumulate and cause planning sessions to under-read project maturity.
- A single stale note in a portfolio directive can cause an entire project to be treated
  as lower-priority across multiple sessions.
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.247395+00:00'
updated_at: '2026-06-11 22:41:19.247395+00:00'
---

# stale-deferral-note-verification

## description

When a plan document contains a deferral note (e.g. 'queued behind X'), treat it as a flag requiring verification rather than accepting it at face value. The blocking condition may have already been resolved.
