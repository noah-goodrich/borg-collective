---
id: obs-20260416-precommit-stash-unstaged
session_date: '2026-04-16'
project: borg-collective
tool: cursor
tags:
- pre-commit
- git
- stash
- hooks
- reveal
category: tool_behavior
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.248234+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260416-precommit-stash-unstaged

## content

The pre-commit hook stashed unstaged files during the commit cycle. This is the hook's normal stash/restore behaviour (it stashes unstaged changes so checks run only against staged content), but it can appear as an error or unexpected state change if you're not familiar with the pattern. All checks (ruff, mypy, pytest) were skipped because no Python files were staged — this is correct behaviour, not a gap in coverage.

## resolution

No action required. Recognise the stash/restore log lines as normal hook operation. If Python files are staged in future commits, the checks will run. Do not mistake 'checks skipped — no matching files staged' for a hook misconfiguration.
