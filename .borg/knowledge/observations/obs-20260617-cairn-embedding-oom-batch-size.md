---
id: obs-20260617-cairn-embedding-oom-batch-size
session_date: '2026-06-17'
project: borg-collective
tool: claude-code
tags:
- cairn
- embeddings
- oom
- batch-processing
category: performance
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-17 18:01:10.027516+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260617-cairn-embedding-oom-batch-size

## content

Re-embedding the full cairn knowledge graph in a single batch causes OOM. Chunking at 50 records/batch was sufficient to complete without memory errors on a graph of ~2,900 records.

## resolution

Always chunk embedding calls when processing large graphs. 50 records/batch is a known-safe size for the current deployment.
