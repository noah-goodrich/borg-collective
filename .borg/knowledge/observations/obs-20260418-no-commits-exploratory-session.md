---
id: obs-20260418-no-commits-exploratory-session
session_date: '2026-04-18'
project: borg-collective
tool: cursor
tags:
- workflow
- session-hygiene
- commits
- borg
category: pattern_discovered
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 20:39:25.071381+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260418-no-commits-exploratory-session

## content

Sessions that are purely diagnostic or environment-setup can end with zero commits while leaving several untracked files (checkpoints, directives, local config). These accumulate silently and are easy to lose or misattribute in a later `git status`. The three untracked files from this session (.borg/checkpoints/, docs/plans/directives/, .claude/settings*) span at least two prior dates, suggesting the pattern recurs across sessions.


## resolution

At session close, run `git status --short` and make an explicit triage decision for each untracked file: commit, gitignore, or delete. Do not defer to the next session unless a checkpoint note records the intent.

