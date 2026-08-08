---
id: cairn-outbox-host-side-only-2026-06-09
date: '2026-06-10'
project: cairn
domain: durability
tags:
- outbox
- docker
- devcontainer
- durability
- filesystem
alternatives: []
applies_to: []
confidence: 0.97
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260610-1630-cairn
created_at: '2026-06-10 16:50:37.415888+00:00'
updated_at: '2026-06-10 16:50:37.415888+00:00'
---

# cairn-outbox-host-side-only-2026-06-09

## decision

The outbox must be operated host-side (apfs). The devcontainer's /home and /tmp are overlay (ephemeral) and not in the FS allowlist.

## context

Empirical finding during devcontainer deployment testing of the outbox slice.

## reasoning

overlay filesystems are ephemeral — F_FULLFSYNC guarantees are meaningless and data written there does not survive container restarts. The host apfs path is the only durable option.
