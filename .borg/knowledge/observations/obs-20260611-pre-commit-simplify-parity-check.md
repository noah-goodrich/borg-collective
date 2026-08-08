---
id: obs-20260611-pre-commit-simplify-parity-check
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- code-quality
- simplify
- hooks
- parity
- review
category: pattern_discovered
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.341917+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-pre-commit-simplify-parity-check

## content

Running /simplify on a pair of sibling scripts (borg-link-up.sh / borg-link-down.sh) surfaced three independent issues that a single-file review would have missed: the unreachable .gitignore negation, a missing PATH comment for developer orientation, and the asymmetric timeout. Pairwise review of sibling files catches divergence that accumulates silently over time.

## resolution

When reviewing shell hook pairs (up/down, start/stop, pre/post), explicitly diff them for structural parity — comments, guards, timeout wrappers, error handling — not just functional correctness in isolation.
