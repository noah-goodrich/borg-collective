---
id: obs-20260616-cli-bypass-embeddings-silent-bug
session_date: '2026-06-16'
project: cairn
tool: claude-code
tags:
- cairn
- embeddings
- cli
- service
- search
- data-consistency
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260616-0914-cairn
superseded_by: null
created_at: '2026-06-16 10:27:02.542630+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260616-cli-bypass-embeddings-silent-bug

## content

cairn's cli.py record_* functions bypassed service.py and wrote directly to the data layer. Records were saved to the DB but embeddings were never generated. This made all CLI-recorded knowledge silently unsearchable — it existed in the database but would never appear in similarity search results. No error was raised; the CLI reported success.

## resolution

Repointed all CLI write entrypoints through cairn.service. Added an 8th fitness invariant (AST-assert write entrypoints route through service) and an integration test: record via CLI → search → assert record appears in results.
