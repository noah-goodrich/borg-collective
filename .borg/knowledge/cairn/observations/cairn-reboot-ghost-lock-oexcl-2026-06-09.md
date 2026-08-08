---
id: cairn-reboot-ghost-lock-oexcl-2026-06-09
session_date: '2026-06-10'
project: cairn
tool: claude-code
tags:
- filesystem
- locking
- durability
- outbox
- oexcl
category: gotcha
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260610-1630-cairn
superseded_by: null
created_at: '2026-06-10 16:50:37.421978+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# cairn-reboot-ghost-lock-oexcl-2026-06-09

## content

A process that holds an O_EXCL lock file and crashes without cleanup leaves a ghost lock that blocks all subsequent drain attempts forever, since O_EXCL open fails on an existing file regardless of whether the owner process is still alive.

## resolution

Implement reboot-safe lease reclaim: store boot-id and monotonic + wall deadline inside the lock JSON. On claim, reclaim if: boot-id differs from current (process died in a prior boot), OR ctime predates boot, OR both wall and monotonic deadlines have elapsed. NEVER rely on file mtime for lease expiry — clock skew can cause premature reclaim.
