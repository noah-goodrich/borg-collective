---
id: deferred-untracked-file-routing
project: borg-collective
domain: git-workflow
tags:
- git
- gitignore
- housekeeping
- untracked-files
preconditions: []
steps:
- Run `git status` and `git ls-files --others --exclude-standard` to enumerate all
  untracked files
- 'Group files by destination: files that belong to existing features, new standalone
  files, files that should be gitignored'
- Audit .gitignore for erroneous rules that may be suppressing legitimate negation
  patterns (e.g., a bare `.borg/` rule blocking `!.borg/checkpoints/`)
- Add new gitignore entries for tool/IDE directories that should never be tracked
  (e.g., `.claude/`, vendor temp dirs)
- Commit all routable files in a single PR with clear grouping in the commit message
- Note any files that belong to an open feature branch — leave them untracked with
  a comment in the session checkpoint
pitfalls:
- A broad gitignore pattern (e.g., `.borg/`) can silently swallow a negation rule
  (`!.borg/checkpoints/`) — always check rule ordering when negations seem not to
  work
- Files belonging to an open PR branch should NOT be committed to main; instead, note
  them explicitly so they land with the correct PR
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.468327+00:00'
updated_at: '2026-06-11 22:41:19.468327+00:00'
---

# deferred-untracked-file-routing

## description

Batch-route all deferred untracked files into a single cleanup PR rather than committing them piecemeal, to keep main clean and give reviewers a complete picture of what's being ingested
