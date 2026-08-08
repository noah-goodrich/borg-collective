---
id: obs-20260616-gitignore-negation-swallowed
session_date: '2026-06-16'
project: borg-collective
tool: claude-code
tags:
- git
- gitignore
- negation
- directories
- checkpoints
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.220783+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260616-gitignore-negation-swallowed

## content

A `.gitignore` line of `.borg/` followed by `!.borg/checkpoints/` silently fails to un-ignore the checkpoints directory. Git's rule is: once a directory is excluded, no rule can re-include files inside it. The negation line appears valid but has zero effect, so checkpoint files remain untracked as if the negation didn't exist.

## resolution

Remove the parent directory ignore (`.borg/`) so the negation `!.borg/checkpoints/` can fire. If other contents of `.borg/` must still be ignored, add explicit ignore lines for each sub-path instead of ignoring the parent.
