---
id: atomic-name-inversion-swap
project: borg-collective
domain: infrastructure
tags:
- git
- rename
- hooks
- lifecycle
- refactor
preconditions: []
steps:
- 'Step 1 — Three-move rename: git mv A A.swap; git mv B A; git mv A.swap B'
- Step 2 — Update file headers/comments inside the renamed files to reflect their
  new semantics.
- Step 3 — Update all registration/configuration sites (e.g. settings.json hook entries,
  cmd_setup calls) to use the corrected names.
- Step 4 — Update all live environment copies (installed hooks dirs, installed skills
  dirs, settings files outside the repo).
- Step 5 — Update all documentation and prose references (README, CLAUDE.md, install.sh,
  skill SKILL.md files, help text).
- Step 6 — Update all test fixtures and variables that reference the old names.
- Step 7 — Syntax-check everything (zsh -n, bash -n, jq empty) and run full test suite.
- Step 8 — Commit as a single atomic commit; a partial swap leaves the environment
  in a confused state.
pitfalls:
- Do not run /simplify or any other refactor pass before the swap is complete — findings
  will reference the old names and churn.
- 'References are spread across more files than expected: hook registrations, skill
  SKILL.md files, nudge scripts, lib comment strings, test variable names, memory
  files, and canonical config templates all need touching.'
- Live environment files (outside the repo) must be updated in the same session; the
  repo and installed copies will diverge otherwise.
- Partial completion leaves SessionStart and Stop hooks pointing at semantically wrong
  scripts — sessions will silently download when they should upload and vice versa.
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 20:39:25.137011+00:00'
updated_at: '2026-06-11 20:39:25.137011+00:00'
---

# atomic-name-inversion-swap

## description

Safely swap two filenames that are exchanging identities in the same directory, then propagate all content and reference updates atomically before committing.
