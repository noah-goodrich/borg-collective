---
id: borg-sync-file-helper-extraction
project: borg-collective
domain: infrastructure
tags:
- shell
- dry
- file-sync
- helper
- lib
preconditions: []
steps:
- Identify all call sites that copy/sync a config file (e.g., borg.zsh, drone.zsh,
  borg-start.sh)
- Extract the mtime comparison and copy logic into a single function (e.g., `_borg_sync_file
  src dst`) in a lib/ file
- Source the lib file from each entry point before calling the helper
- 'Handle the symlink-to-file migration case explicitly: if dst is a symlink, remove
  it before copying'
- Verify all entry points (session start, `borg setup`) call the helper so healing
  is guaranteed
pitfalls:
- If the lib source path in any entry point is wrong (e.g., relative vs absolute),
  the helper silently doesn't load and the old broken code runs — always verify with
  `type _borg_sync_file` after sourcing
- Tracking copy success with a sentinel variable across subshells is unreliable; check
  file state directly instead
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 20:39:24.966267+00:00'
updated_at: '2026-06-11 20:39:24.966268+00:00'
---

# borg-sync-file-helper-extraction

## description

Extract repeated file-sync logic into a shared shell helper to ensure consistent mtime-based copy behavior across all entry points
