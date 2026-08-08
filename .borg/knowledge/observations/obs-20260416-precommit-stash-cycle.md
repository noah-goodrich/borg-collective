---
id: obs-20260416-precommit-stash-cycle
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- pre-commit
- git
- stash
- hooks
- ruff
- mypy
- pytest
category: tool_behavior
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 20:39:25.017151+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260416-precommit-stash-cycle

## content

pre-commit hooks stash unstaged files before running checks, then restore them after. This appears in terminal output as stash/restore activity and can look like an error or data-loss event. When no Python files are staged, ruff/mypy/pytest hooks are skipped entirely — they do not run against the working tree.

## resolution

No action required. Confirm 'All checks passed' appears in output. If the stash restore fails (e.g. merge conflict), run 'git stash pop' manually. Do not interpret the stash activity as hook failure.
