---
id: project-rename-cosmetic-sweep
project: borg-collective
domain: code-quality
tags:
- rename
- wallpaper-kit
- reveal
- grep
- batch-replace
preconditions: []
steps:
- 'Run a scoped grep to enumerate affected files: `grep -r ''old.name'' /path/to/project
  --include=''*.py'' --include=''*.md'' --include=''*.yml'' -l`'
- 'Triage results: separate cosmetic occurrences (docstrings, script comments, compose
  service names) from functional ones (import paths, environment variables, external
  service references).'
- Batch-replace cosmetic occurrences with sed or IDE find-replace.
- Handle functional occurrences individually with targeted edits and verification.
- 'Commit as a single housekeeping commit with a clear message (e.g. ''chore: sweep
  stale wallpaper-kit references'').'
- Archive or update any directives that still reference the old name as a pending
  blocker.
pitfalls:
- Compose service names may be referenced in scripts or CI config outside the main
  project tree — check dependent repos.
- Do not conflate cosmetic sweep with a full rename refactor; keep scope small to
  avoid introducing regressions.
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.247885+00:00'
updated_at: '2026-06-11 22:41:19.247886+00:00'
---

# project-rename-cosmetic-sweep

## description

Enumerate and batch-replace stale project name references after a rename, scoped to cosmetic locations (docstrings, comments, compose service names) rather than functional identifiers.
