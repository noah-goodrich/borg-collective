---
id: cairn-knowledge-graph-empty-audit-log-2026-06-09
session_date: '2026-06-10'
project: cairn
tool: claude-code
tags:
- knowledge-graph
- borg
- sessions
- capture
- backfill
category: domain_knowledge
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260610-1630-cairn
superseded_by: null
created_at: '2026-06-10 16:50:37.423478+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# cairn-knowledge-graph-empty-audit-log-2026-06-09

## content

After multiple sessions, the knowledge graph had only sessions recorded — no decisions, patterns, or observations. SessionStart searches returned zero useful context. The hooks were functioning as an audit log, not a knowledge graph.

## resolution

Knowledge capture must be an active authored step. The v0.2 design uses borg-link-up skill for LLM extraction of decisions/patterns/observations at session end, POSTed via MCP. Historical backfill of checkpoints is required to seed the graph.
