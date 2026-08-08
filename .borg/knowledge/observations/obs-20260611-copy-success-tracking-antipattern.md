---
id: obs-20260611-copy-success-tracking-antipattern
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- shell
- subshell
- variable-scope
- anti-pattern
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 20:39:24.968419+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-copy-success-tracking-antipattern

## content

Tracking whether a file copy succeeded via a variable set inside a subshell or piped command doesn't propagate back to the parent shell. The parent sees the variable as unset/false even when the copy succeeded. This was recorded as a Learned entry in CLAUDE.md.

## resolution

Instead of `copied=true` inside a conditional subshell, check the resulting file state directly (e.g., `[[ -f dst ]]` or compare mtimes after the operation).
