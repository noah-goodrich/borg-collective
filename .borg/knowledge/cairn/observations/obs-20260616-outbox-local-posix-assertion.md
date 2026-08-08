---
id: obs-20260616-outbox-local-posix-assertion
session_date: '2026-06-16'
project: cairn
tool: claude-code
tags:
- cairn
- outbox
- posix
- nfs
- o_excl
- atomicity
category: gotcha
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260616-0914-cairn
superseded_by: null
created_at: '2026-06-16 10:27:03.270698+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260616-outbox-local-posix-assertion

## content

O_EXCL lockfile atomicity is not guaranteed on NFS or overlay filesystems. An outbox relying on O_EXCL for mutual exclusion will have silent race conditions if the outbox directory is on a network or container overlay mount.

## resolution

Assert at startup that the outbox root (~/.config/cairn/outbox/) is on a local POSIX filesystem. Fail hard (not silently) if the assertion fails.
