---
id: obs-20260611-two-step-git-mv-swap
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- git
- rename
- swap
- hooks
- lifecycle
category: pattern_discovered
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.327368+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-two-step-git-mv-swap

## content

Swapping two filenames in git (A→B, B→A) requires a three-step intermediate rename to avoid collision: mv A A.swap, mv B A, mv A.swap B. Git mv on case-insensitive filesystems (macOS) will silently do nothing or collide if you attempt a direct swap in one step.

## resolution

Documented as the required approach in the next-session plan. Use a .swap suffix as the intermediate name.
