---
id: obs-20260507-hook-path-completeness
session_date: '2026-06-16'
project: borg-collective
tool: claude-code
tags:
- hook
- PATH
- borg-link-up
- borg-link-down
- shell
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.352066+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260507-hook-path-completeness

## content

`borg-link-down.sh` and `borg-link-up.sh` had incomplete PATH definitions, meaning binaries installed via pipx or similar tools might not be found when hooks executed in a non-interactive shell context.

## resolution

Fixed in `7c1e2d1` — PATH completeness added at lines `borg-link-down.sh:20` and `borg-link-up.sh:17`. Any new hook script should include an explicit PATH definition covering pipx, homebrew, and system bin directories.
