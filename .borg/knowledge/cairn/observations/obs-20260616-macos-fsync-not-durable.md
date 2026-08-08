---
id: obs-20260616-macos-fsync-not-durable
session_date: '2026-06-16'
project: cairn
tool: claude-code
tags:
- macos
- fsync
- durability
- filesystem
- apfs
- data-loss
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260616-0914-cairn
superseded_by: null
created_at: '2026-06-16 10:27:03.291113+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260616-macos-fsync-not-durable

## content

On macOS, fsync() does NOT guarantee data reaches the physical storage medium. It only flushes to the OS buffer cache. A power loss after a successful fsync() return can still lose the data. F_FULLFSYNC (via fcntl(fd, F_FULLFSYNC)) is required to force the drive's write cache to flush on macOS/APFS.

## resolution

Use fcntl.fcntl(fd, fcntl.F_FULLFSYNC) on macOS (detected via sys.platform == 'darwin'), fall back to os.fsync() on other platforms. This was implemented as durable_fsync() in outbox.py.
