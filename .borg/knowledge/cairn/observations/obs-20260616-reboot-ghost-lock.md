---
id: obs-20260616-reboot-ghost-lock
session_date: '2026-06-16'
project: cairn
tool: claude-code
tags:
- locking
- reboot
- filesystem
- outbox
- liveness
- O_EXCL
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260616-0914-cairn
superseded_by: null
created_at: '2026-06-16 10:27:03.291908+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260616-reboot-ghost-lock

## content

An O_EXCL lock file written by a process that crashes or is killed on reboot persists on disk. On next boot, no process holds the lock, but no process will ever release it either. This permanently blocks all drain attempts on that entry (liveness_stuck), and if queue_nonempty uses the pending/ directory, it also blocks the DOWN→UP demotion gate forever.

## resolution

Implement reboot-safe lease reclaim: check boot-id change (Linux /proc/sys/kernel/random/boot_id), ctime-predates-boot (parse kern.boottime on macOS via sysctl), and wall+mono deadline as a three-way OR predicate. All three are needed for cross-platform coverage.
