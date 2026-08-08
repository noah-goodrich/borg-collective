---
id: obs-20260417-untracked-files-session-end
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- git
- untracked
- session-hygiene
- settings.local.json
category: pattern_discovered
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.262153+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260417-untracked-files-session-end

## content

Three meaningful artifacts were left untracked/unstaged at session end: `.claude/settings.json`, `.claude/settings.local.json`, and `docs/plans/directives/2026-04-14-portfolio-mvp-pivot.md`, plus an unstaged `.gitignore` change. The session debrief correctly identified this but no commit was made. `settings.local.json` has an unresolved question: should it be gitignored or committed? Its contents were not inspected during the session.

## resolution

Before next session: (1) inspect `settings.local.json` to determine if it contains secrets/local paths — if so, add to `.gitignore`; if it's safe, decide whether to commit. (2) Commit the other three artifacts. Establish a convention: `settings.local.json` pattern typically implies local-only overrides and should generally be gitignored.
