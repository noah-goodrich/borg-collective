---
id: cairn-overlay-fs-not-durable-2026-06-09
session_date: '2026-06-10'
project: cairn
tool: claude-code
tags:
- docker
- devcontainer
- filesystem
- durability
- overlay
- outbox
category: domain_knowledge
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260610-1630-cairn
superseded_by: null
created_at: '2026-06-10 16:50:37.421524+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# cairn-overlay-fs-not-durable-2026-06-09

## content

The cairn devcontainer's $HOME and /tmp are overlay filesystems (ephemeral). The workspace bind-mount uses fakeowner/FUSE with questionable durability guarantees. F_FULLFSYNC on an overlay fs does not provide the durability guarantee it does on apfs.

## resolution

Outbox enqueue and cairn drain must run host-side on apfs. The devcontainer is a valid target for the cairn-server HTTP service only.
