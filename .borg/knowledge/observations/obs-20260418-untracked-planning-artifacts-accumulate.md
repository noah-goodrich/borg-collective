---
id: obs-20260418-untracked-planning-artifacts-accumulate
session_date: '2026-04-18'
project: borg-collective
tool: cursor
tags:
- borg
- checkpoints
- git
- workflow
- hygiene
category: pattern_discovered
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.280172+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260418-untracked-planning-artifacts-accumulate

## content

Multiple first-class planning and checkpoint artifacts accumulated as untracked files across sessions without being committed: `.borg/checkpoints/2026-04-14-1600.md`, `docs/plans/directives/2026-04-14-portfolio-mvp-pivot.md`, and the misplaced debrief. Each was created during normal borg workflow but the commit phase was skipped (session cut short or exploratory-only). Over multiple sessions this creates invisible project state that the next developer cannot see from `git log`.


## resolution

End every borg session — even exploratory ones — with an explicit `git add -A && git status` review before closing tmux. If work is not ready to commit, stage it as a WIP commit (`git commit -m "wip: <slug>"`) so state is at least visible in the log. Consider adding a borg session-end hook that warns when `.borg/`, `docs/plans/`, or `templates/` contain untracked files.

