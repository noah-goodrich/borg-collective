---
id: obs-20260611-gitignore-negation-unreachable
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- git
- gitignore
- negation
- directory-ignore
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.340911+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-gitignore-negation-unreachable

## content

A .gitignore entry of `dir/` followed by `!dir/subdir/` does NOT un-ignore the subdirectory. Git's rule is: once a directory is matched by an ignore pattern, its contents are never re-evaluated against subsequent negation patterns. The `!dir/subdir/` line was silently dead.

## resolution

Remove or narrow the blanket `dir/` ignore rule. If only some contents of the directory should be ignored, enumerate them explicitly rather than ignoring the parent directory and attempting to negate children.
