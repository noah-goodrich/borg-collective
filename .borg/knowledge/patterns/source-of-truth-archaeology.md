---
id: source-of-truth-archaeology
project: borg-collective
domain: architecture
tags:
- decision-recovery
- session-history
- repo-ownership
preconditions: []
steps:
- Identify the ambiguity (e.g., contradictory directives in two repos)
- Search handoff docs, dispatch logs, or git log for the earliest mention of the relationship
- Locate the originating session record (e.g., f9ef8d07) and read its stated rationale
- Update any downstream docs or code that contradict the recovered decision
- Record the corrected source-of-truth in the canonical repo's handoff doc
pitfalls:
- Without this step it's easy to accidentally invert the intended data-flow direction
- Downstream repos (like claude-plugins) may accumulate stale or backwards directives
  over time
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.460835+00:00'
updated_at: '2026-06-11 22:41:19.460835+00:00'
---

# source-of-truth-archaeology

## description

When repo ownership or data-flow direction is ambiguous, search session/dispatch logs by commit hash or session ID to recover the original decision rationale rather than re-litigating from first principles
