---
id: 20260609-80-20-one-verb-at-a-time
date: '2026-06-16'
project: borg-collective
domain: architecture
tags:
- mechanism-layer
- plugins
- 80-20
- directives
- incremental
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260616-0347-orchestrator
created_at: '2026-06-16 10:27:02.512278+00:00'
updated_at: '2026-06-16 10:27:02.512279+00:00'
---

# 20260609-80-20-one-verb-at-a-time

## decision

File follow-on directives for mechanism-layer extraction one verb at a time (scan/scoring, cairn-client, search), each parented to the completed reaper directive, rather than batching all verbs into a single large plan.

## context

The reaper slice was proven via PR #41. Remaining verbs (scan/scoring, cairn-client, search) have similar 80/20 extraction potential but different risk profiles.

## reasoning

Each verb has distinct call-site complexity. A per-verb directive lets each one be reviewed, scoped, and merged independently, avoiding a monolithic PR that's hard to review and easy to partially break.
