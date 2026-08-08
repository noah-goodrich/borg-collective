---
id: feat-branch-to-versioned-release
project: cairn
domain: release-management
tags:
- git
- semver
- borg-collective
- optional-dependency
preconditions: []
steps:
- Resolve any uncommitted ambiguities on the feat branch (e.g. `.borg-project` deletion
  intent) and document the decision in the PR description.
- Open a PR from the feat branch to main with a descriptive title; ensure CI passes.
- Squash-merge the PR to keep main history linear.
- 'Tag the merge commit: `git tag -a v0.1.0 -m ''Cairn MCP Phase 1''` and push the
  tag.'
- Update the consuming plugin (borg-collective) to declare `cairn>=0.1.0` as an optional
  extra now that a real version exists.
- Move the originating PROJECT_PLAN to `docs/plans/assimilated/` per the ready-to-assimilate
  handoff doc.
pitfalls:
- Tagging before the feat branch merges means the tag points at a commit not on main
  — always tag from main after the squash-merge.
- Optional-dependency pins in consuming plugins are blocked until the tag exists;
  don't let plugin work proceed against an untagged SHA.
- Squash-merge discards individual commit messages — ensure the PR description captures
  the design rationale before merging.
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1925-cairn
superseded_by: null
created_at: '2026-06-11 20:31:18.008052+00:00'
updated_at: '2026-06-11 20:31:18.008052+00:00'
---

# feat-branch-to-versioned-release

## description

Workflow for landing a feature branch and cutting a semver tag so a consuming plugin can pin an optional dependency against a real version.
