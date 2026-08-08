---
id: obs-20260611-cli-null-embeddings-silent-failure
session_date: '2026-06-11'
project: cairn
tool: cursor
tags:
- cli
- embeddings
- semantic-search
- db-insert
- service-layer
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1925-cairn
superseded_by: null
created_at: '2026-06-11 20:31:18.035934+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-cli-null-embeddings-silent-failure

## content

CLI-recorded knowledge (decisions, observations, patterns) had NULL embeddings because cli.py called db.insert_* directly, bypassing the service layer that generates embeddings before insert. Rows were written successfully with no error, but were completely invisible to semantic search. The bug was silent — no exception, no warning, no indication in the CLI output that the record was unsearchable.

## resolution

Route all CLI record_* calls through cairn.service.record_* (matching api.py and mcp.py). Add fitness invariant to prevent regression. Add integration test that asserts non-NULL embedding and search returnability for CLI-recorded rows.
