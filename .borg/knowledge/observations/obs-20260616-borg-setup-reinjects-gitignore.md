---
id: obs-20260616-borg-setup-reinjects-gitignore
session_date: '2026-06-16'
project: borg-collective
tool: claude-code
tags:
- gitignore
- install.sh
- borg-setup
- idempotency
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.449801+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260616-borg-setup-reinjects-gitignore

## content

borg setup (via install.sh) re-injects a `.borg/` line into each project's .gitignore on every run, even after that line was manually removed and the fix merged in PR #29. The root cause is in install.sh (around line 200+) where the setup routine unconditionally appends `.borg/` when initialising per-project gitignore entries — it does not check whether the line already exists or whether it should be scoped more narrowly.

## resolution

Fix install.sh to (a) check for the existing line before appending, and (b) append `.borg/state.json` specifically rather than `.borg/`. The broader `.borg/` exclusion was the original bug.
