---
id: multi-repo-session-commit-workflow
project: cairn
domain: code-quality
tags:
- git
- multi-repo
- workflow
- simplify
preconditions: []
steps:
- Run /simplify on each changed file before committing to reduce noise in the diff
- Commit repos in dependency order (infrastructure last, or by blast radius)
- Verify end-to-end smoke test after each repo commit, not just at the end
- Document the three-repo span in the commit message or PR description so reviewers
  understand the scope
pitfalls:
- Changes across cairn, borg-collective, and dotfiles are tightly coupled — committing
  only one repo can leave the system in a broken intermediate state
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1925-cairn
superseded_by: null
created_at: '2026-06-11 23:12:50.708775+00:00'
updated_at: '2026-06-11 23:12:50.708775+00:00'
---

# multi-repo-session-commit-workflow

## description

Workflow for committing changes that span multiple repositories after a cross-cutting session
