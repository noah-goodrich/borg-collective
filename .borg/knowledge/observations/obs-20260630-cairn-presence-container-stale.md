---
id: obs-20260630-cairn-presence-container-stale
session_date: '2026-06-30'
project: borg-collective
tool: claude-code
tags:
- cairn
- presence
- docker
- deployment
- migration
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260630-2202-borg-collective
superseded_by: null
created_at: '2026-06-30 22:03:12.822642+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260630-cairn-presence-container-stale

## content

The cairn presence backend (PR #12, migration 004) was merged to `main`, but the live `cairn-api` container at `127.0.0.1:8767` was built from an image predating the PR. All `/presence/*` endpoints return 404 despite the code being merged, because the running container doesn't include the new routes or migration.

## resolution

Requires: (1) rebuild the `cairn-api` Docker image from current `main`, (2) restart the container, (3) apply migration 004. Until then, treat presence as non-functional regardless of what `main` contains. Block any presence consumers (hooks) on this rebuild step.
