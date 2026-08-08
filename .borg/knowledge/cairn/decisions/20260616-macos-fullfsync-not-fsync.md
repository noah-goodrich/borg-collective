---
id: 20260616-macos-fullfsync-not-fsync
date: '2026-06-16'
project: cairn
domain: infrastructure
tags:
- durability
- macos
- fsync
- filesystem
- zero-loss
alternatives: []
applies_to: []
confidence: 0.9
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260616-0914-cairn
created_at: '2026-06-16 10:27:03.286080+00:00'
updated_at: '2026-06-16 10:27:03.286081+00:00'
---

# 20260616-macos-fullfsync-not-fsync

## decision

Use F_FULLFSYNC (fcntl) on macOS instead of fsync() for durable writes in the outbox

## context

Implementing the durable enqueue-first filesystem queue; needed guarantee that data reaches storage media before acknowledging a write

## reasoning

On macOS, fsync() only flushes to the OS buffer cache — it does NOT guarantee data reaches the physical medium. F_FULLFSYNC forces the drive's write cache to flush. Without this, a power loss after fsync() but before media write silently loses the enqueued entry, defeating zero-loss.
