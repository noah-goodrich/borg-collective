---
id: 20260616-outbox-host-side-only
date: '2026-06-16'
project: cairn
domain: infrastructure
tags:
- devcontainer
- filesystem
- durability
- deployment
- outbox
alternatives: []
applies_to: []
confidence: 0.9
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260616-0914-cairn
created_at: '2026-06-16 10:27:03.287777+00:00'
updated_at: '2026-06-16 10:27:03.287778+00:00'
---

# 20260616-outbox-host-side-only

## decision

Outbox must be operated host-side (APFS) rather than inside the devcontainer

## context

Empirical finding during implementation: devcontainer $HOME and /tmp are overlay (ephemeral) and the workspace bind mount is fakeowner/FUSE with questionable durability

## reasoning

overlay filesystems are ephemeral by definition — a container restart loses all outbox entries. FUSE/fakeowner layers may not honor F_FULLFSYNC semantics. Only APFS on the host provides the durability guarantees the outbox requires. cairn drain and enqueue must run on the host; the service is reached over HTTP.
