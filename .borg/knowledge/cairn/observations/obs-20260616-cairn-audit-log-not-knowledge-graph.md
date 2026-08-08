---
id: obs-20260616-cairn-audit-log-not-knowledge-graph
session_date: '2026-06-16'
project: cairn
tool: claude-code
tags:
- cairn
- borg
- knowledge-graph
- audit-log
- empty-data
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260616-0914-cairn
superseded_by: null
created_at: '2026-06-16 10:27:03.268128+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260616-cairn-audit-log-not-knowledge-graph

## content

cairn was reachable and the borg hooks were calling it (56 session rows), but it was functioning as an audit log, not a knowledge graph. The hooks query decisions/patterns/observations which were nearly empty (2 decisions, 1 observation, all from cairn itself). Session-start searches returned 0 bytes. Nobody was writing knowledge.

## resolution

Diagnosis drove the v0.2 redesign: separate the documents/knowledge store from the session audit log, and make capture a first-class plugin responsibility.
