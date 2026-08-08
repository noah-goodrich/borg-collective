---
id: borg-collective-release-recipe
project: borg-collective
domain: infrastructure
tags:
- borg-collective
- release
- brew
- versioning
preconditions: []
steps:
- Confirm CI green on the feature PR
- 'Squash-merge and delete branch: `gh pr merge <N> --squash --delete-branch`'
- Cut a version tag following the existing pattern (see v0.7.11 commit 208c97e)
- Update brew tap to point to new release
- 'On target machine: `brew upgrade borg-collective && borg setup`'
- 'Verify skills installed: `grep -c ''Local Extensions:'' ~/.claude/skills/borg-plan/SKILL.md`
  should return 3'
pitfalls:
- Modified SKILL.md files only reach ~/.claude/skills/ via `borg setup` which runs
  after `brew upgrade` — changes are 'edited but unproven' until that sequence completes.
- Do not verify protocol behavior against the repo copy; always verify against the
  installed copy under ~/.claude/skills/.
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.393303+00:00'
updated_at: '2026-06-11 22:41:19.393304+00:00'
---

# borg-collective-release-recipe

## description

Standard release flow after merging a feature PR: squash-merge, tag, update brew tap. Reference commit 208c97e (v0.7.11) for exact recipe.
