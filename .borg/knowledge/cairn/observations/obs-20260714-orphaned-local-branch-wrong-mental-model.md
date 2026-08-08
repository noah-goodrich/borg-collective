---
id: obs-20260714-orphaned-local-branch-wrong-mental-model
session_date: '2026-07-14'
project: cairn
tool: claude-code
tags:
- git
- branches
- release
- mental-model
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260714-0405-cairn
superseded_by: null
created_at: '2026-07-14 04:06:54.533779+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260714-orphaned-local-branch-wrong-mental-model

## content

`release/0.5.0` existed as a local branch with no remote counterpart, creating a false mental model that it was an active release branch. In reality it was an orphaned duplicate version bump; `main` is the source of truth. The stale branch caused confusion about which branch to use for the 0.5.1 release.

## resolution

Deleted the orphaned local branch. The correct model: cairn does not use long-lived release branches; `main` is canonical and releases are tagged (once tags are in use).
