---
id: legacy-name-sweep-batch-replace
project: borg-collective
domain: code-quality
tags:
- rename
- grep
- batch-replace
- reveal
- wallpaper-kit
preconditions: []
steps:
- 'Run: grep -r ''<old-name>'' <project-root> --include=''*.py'' --include=''*.md''
  --include=''*.yml'' -l to enumerate affected files.'
- 'Triage results: separate cosmetic occurrences (docstrings, comments, script headers)
  from functional ones (service names, env vars, import paths).'
- Fix functional references first in a single commit; cosmetic in a follow-up.
- Rename compose service name explicitly — it does not get caught by simple string
  grep if it matches a substring.
- Archive or delete any directive/plan files that reference only the old name and
  are otherwise superseded.
pitfalls:
- ~24 files sounds small but can still take ~1h if compose service names and cross-repo
  directive files are included.
- Do not conflate cosmetic docstring cleanup with functional rename — ship them separately
  to keep diffs reviewable.
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 20:39:25.016685+00:00'
updated_at: '2026-06-11 20:39:25.016685+00:00'
---

# legacy-name-sweep-batch-replace

## description

Enumerate and batch-replace stale project name references across a codebase after a rename.
