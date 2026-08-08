---
id: obs-20260616-nanoprobe-evidence-fields-required
session_date: '2026-06-16'
project: borg-collective
tool: claude-code
tags:
- nanoprobe
- agents-jsonl
- schema
- evidence
category: domain_knowledge
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.468684+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260616-nanoprobe-evidence-fields-required

## content

The agents.jsonl schema was extended with two new required fields: evidence_found (bool) and evidence_score (0–3). All 11 new nanoprobe bats tests validate these fields are present on every record write, not just on positive evidence cases. Consumers of agents.jsonl can now rely on these fields always being present.

## resolution

When adding new required fields to an append-only log schema, add bats tests that assert field presence on all code paths (not just the happy path) to prevent schema drift in future edits.
