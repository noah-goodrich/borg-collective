---
id: obs-20260415-uncommitted-directive-invisible-to-borg-link
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- git
- borg
- workflow
- directives
- traceability
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 20:39:24.990348+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260415-uncommitted-directive-invisible-to-borg-link

## content

The portfolio pivot directive (docs/plans/directives/2026-04-14-portfolio-mvp-pivot.md) was filed mid-session but left untracked/uncommitted. borg link (and any git-history-based tooling) is blind to untracked files. The directive was actively shaping decisions in the session but had no durable record in the repo. If the session had ended without committing it, the rationale for the Supabase pivot would exist only in session memory.

## resolution

Identified as a next-step action: git add + git commit with ship: prefix. General pattern: file directives and commit them before acting on them, not after, so that the decision trail is always ahead of the implementation trail.
