---
id: skip-simplify-for-prompt-only-prs
project: borg-collective
domain: code-quality
tags:
- borg-assimilate
- simplify
- workflow
- prompt-engineering
preconditions: []
steps:
- 'Assess PR contents: if all changed files are `.md`, `SKILL.md`, `CLAUDE.md`, or
  similar prompt/doc files, no executable code exists.'
- Skip `/simplify` explicitly with a documented reason in the session checkpoint.
- Proceed directly to commit and push.
pitfalls:
- Forgetting to document the skip reason in the checkpoint can make it look like `/simplify`
  was accidentally omitted rather than intentionally skipped.
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.300870+00:00'
updated_at: '2026-06-16 10:27:02.300870+00:00'
---

# skip-simplify-for-prompt-only-prs

## description

When a PR contains only prompt/markdown edits with no executable code, skip the `/simplify` step in the assimilation workflow.
