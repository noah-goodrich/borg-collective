---
id: obs-20260611-v010-tag-before-style-commits
session_date: '2026-06-11'
project: cairn
tool: cursor
tags:
- git
- tagging
- release
- ruff
- history
category: domain_knowledge
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260611-1925-cairn
superseded_by: null
created_at: '2026-06-11 23:12:50.727353+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-v010-tag-before-style-commits

## content

v0.1.0 was tagged at 7a14048, which is two commits before the ruff format/lint cleanup. The 20-file format pass is a large style-only diff that inflates git blame noise for those files. If the tag is re-pointed to 9953ce4, git log --follow and blame will show the style commit as the most recent touch on many lines.

## resolution

Noted as an optional loose end. Re-tag with `git tag -f v0.1.0 9953ce4 && git push --force origin v0.1.0` if a clean-tree tag matters. No functional difference either way.
