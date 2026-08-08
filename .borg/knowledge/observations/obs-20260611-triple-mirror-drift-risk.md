---
id: obs-20260611-triple-mirror-drift-risk
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- shell
- deduplication
- drift
- architecture
category: domain_knowledge
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.523050+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-triple-mirror-drift-risk

## content

When a shell predicate exists in 3+ locations (lib file, hooks file, SKILL.md prose), divergence is nearly inevitable across PRs. The `_borg_should_reap` predicate had already drifted between its three homes before the mechanism-layer extraction.

## resolution

Collapse to a single `lib/` source of truth immediately when a predicate appears in more than one location. Use the mechanism-layer extraction pattern.
