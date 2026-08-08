---
id: 20260616-reboot-safe-lease-reclaim
date: '2026-06-16'
project: cairn
domain: architecture
tags:
- locking
- lease
- reboot
- outbox
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
created_at: '2026-06-16 10:27:03.287229+00:00'
updated_at: '2026-06-16 10:27:03.287229+00:00'
---

# 20260616-reboot-safe-lease-reclaim

## decision

Reclaim stale outbox claim-locks using a three-way predicate: boot-id changed OR ctime predates boot OR wall+mono deadline exceeded

## context

Outbox uses O_EXCL lock files to claim pending entries for processing. A process crash or reboot leaves a ghost lock that blocks all future drain attempts forever (liveness_stuck).

## reasoning

Boot-id change (Linux) and ctime-predates-boot (macOS/Linux fallback via kern.boottime) catch the reboot-ghost case immediately without waiting for a wall-clock deadline. The wall+mono deadline catches the live-but-hung worker case. All three are needed because: boot-id is Linux-only; ctime is available everywhere but requires parsing kern.boottime on macOS; deadline is the last-resort for long-running processes.
