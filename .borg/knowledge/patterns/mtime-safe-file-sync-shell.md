---
id: mtime-safe-file-sync-shell
project: borg-collective
domain: infrastructure
tags:
- shell
- file-sync
- mtime
- no-python3
- devcontainer
preconditions: []
steps:
- Check if destination is a symlink; if so, remove it before copying (symlink-to-file
  migration)
- If destination does not exist, copy source to destination unconditionally
- If both exist, compare mtimes with `[ source -nt dest ]`; copy only if source is
  newer
- Record copy success in a side-channel variable or log, not by re-stat-ing the file
  (see gotcha)
pitfalls:
- Do not re-stat the destination to confirm the copy succeeded — this is an anti-pattern
  that creates false confidence if the copy silently fails on a read-only filesystem
- On some Linux containers `cp -p` does not preserve mtime from a bind-mounted host
  volume; test inside the target container, not just on the host
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.217707+00:00'
updated_at: '2026-06-11 22:41:19.217707+00:00'
---

# mtime-safe-file-sync-shell

## description

Sync a source file into a destination only when the source is newer, handling the case where the destination may currently be a symlink. No python3 dependency.

