---
id: obs-20260616-devcontainer-overlay-ephemeral
session_date: '2026-06-16'
project: cairn
tool: claude-code
tags:
- devcontainer
- docker
- filesystem
- overlay
- durability
- deployment
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260616-0914-cairn
superseded_by: null
created_at: '2026-06-16 10:27:03.292375+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260616-devcontainer-overlay-ephemeral

## content

The cairn devcontainer's $HOME and /tmp are on overlay filesystem (ephemeral — wiped on container restart). The workspace bind mount uses fakeowner/FUSE which has unverified F_FULLFSYNC semantics. Any outbox operated inside the devcontainer will silently lose all queued entries on container restart.

## resolution

Outbox must be operated host-side on APFS. cairn drain and enqueue commands run on the host; the cairn service is reached over HTTP from the host. The install-time fs allowlist explicitly excludes overlay and FUSE mountpoints.
