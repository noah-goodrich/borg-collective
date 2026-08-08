---
id: obs-20260418-non-git-repos-miss-devcontainer-fixes
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- devcontainer
- git
- cairn
- infrastructure
- multi-repo
category: gotcha
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 20:39:25.063212+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260418-non-git-repos-miss-devcontainer-fixes

## content

Repos that are not git repositories (cairn, snowflake-projects in this session) will have devcontainer.json edits applied on disk but cannot be committed. This means they will silently diverge from the established pattern on the next git clone or fresh setup, and the fix will appear to have been applied when it hasn't been durably captured.

## resolution

Maintain an explicit list of non-git repos that need manual re-application of any infra pattern changes. Long-term: make these proper git repos. Short-term: track in session blockers and apply at next opportunity.
