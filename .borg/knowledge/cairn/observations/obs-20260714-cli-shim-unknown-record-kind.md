---
id: obs-20260714-cli-shim-unknown-record-kind
session_date: '2026-07-14'
project: cairn
tool: claude-code
tags:
- cli
- shim
- record-kinds
- checkpoint-writes
- debugging
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260714-0405-cairn
superseded_by: null
created_at: '2026-07-14 04:06:54.531410+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260714-cli-shim-unknown-record-kind

## content

Checkpoint document writes were silently failing because the `cairn` CLI shim had no `record document` case. The service endpoint (`POST /record/document`, added in v0.2) existed and worked, but the CLI shim only dispatched known record kinds and returned `unknown record kind: document` for anything else. This caused all checkpoint write attempts to fail with no obvious connection to a shim gap.

## resolution

Added the `document` case to both shim files (cairn repo + dotfiles repo) in cairn #29 and dotfiles #6. Verified with a live end-to-end test: `cairn record document ...` → `Recorded document: <id>` → row confirmed in DB.
