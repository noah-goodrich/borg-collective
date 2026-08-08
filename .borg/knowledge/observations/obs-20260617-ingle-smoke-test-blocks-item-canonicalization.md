---
id: obs-20260617-ingle-smoke-test-blocks-item-canonicalization
session_date: '2026-06-17'
project: borg-collective
tool: claude-code
tags:
- ingle
- smoke-test
- item-canonicalization
- blocker
- dependency
category: domain_knowledge
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-17 18:03:01.150338+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260617-ingle-smoke-test-blocks-item-canonicalization

## content

The Ingle shopping smoke test is outstanding and explicitly blocks Item Canonicalization work. This dependency was called out at session end as a carry-over blocker — it has survived at least one full session without being addressed.

## resolution

Before starting any Item Canonicalization work, run the Ingle shopping smoke test and resolve any failures. Treat it as a gate, not a background task.
