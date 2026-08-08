---
id: obs-20260611-partial-inversion-swap-danger
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- lifecycle
- hooks
- settings.json
- inversion
- atomicity
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.327689+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-partial-inversion-swap-danger

## content

The link-up/link-down name inversion touches 20+ locations across source files, installed live env files, settings.json, docs, tests, and memory files. A partial swap leaves the environment in a contradictory state where SessionStart and Stop hooks may be wired to the wrong behavior, causing silent data-direction errors (uploading when should download, or vice versa). There is no safe stopping point mid-swap.

## resolution

Plan explicitly calls for executing the entire swap end-to-end in a single session turn (~20-30 tool calls). Verify with zsh -n, bash -n, jq empty, and full bats suite before committing.
