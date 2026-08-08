---
id: obs-20260630-install-symlink-silent-failure
session_date: '2026-06-30'
project: borg-collective
tool: claude-code
tags:
- install
- symlink
- PATH
- silent-failure
- vinculum
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260630-2202-borg-collective
superseded_by: null
created_at: '2026-06-30 22:03:12.821643+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260630-install-symlink-silent-failure

## content

When `borg sub` spawned `borg-vinculum-watch` by bare name and the binary wasn't symlinked into `$BIN_DIR`, the watcher silently failed to start. `sub` itself reported success (it attempted to spawn, returned 0), but live message delivery never worked. No error was surfaced to the user.

## resolution

Always add new executable scripts to `install.sh`'s symlink section in the same PR that introduces them. Validate installs by running `install.sh` and confirming new binaries appear in `$BIN_DIR` before merging.
