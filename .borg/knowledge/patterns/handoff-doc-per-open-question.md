---
id: handoff-doc-per-open-question
project: borg-collective
domain: project-management
tags:
- handoff
- documentation
- async
- human-decision
preconditions: []
steps:
- Identify each open question or blocker that cannot be resolved without human input.
- 'Write a focused handoff doc at `docs/plans/handoff/YYYY-MM-DD-<slug>.md` covering:
  what the question is, what evidence exists, what options are available, and what
  the recommended action is.'
- List all handoff docs in the session checkpoint's 'Next Session' section.
- In the next session, read all listed handoff docs before doing any other work.
pitfalls:
- Writing handoff docs too vague defeats the purpose — each doc should enable a decision
  without requiring the reader to re-investigate.
- Handoff docs that don't get linked from the checkpoint can be lost; always cross-reference.
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.398444+00:00'
updated_at: '2026-06-16 10:27:02.398444+00:00'
---

# handoff-doc-per-open-question

## description

For each unresolved blocker or decision requiring human judgment at session end, write a dedicated handoff doc capturing the decision criteria, options, and recommended next action. Reference all handoff docs from the session checkpoint.
