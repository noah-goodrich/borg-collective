---
id: simplify-three-agent-before-commit
project: borg-collective
domain: code-quality
tags:
- workflow
- review
- simplify
- pre-commit
preconditions: []
steps:
- Stage all intended changes
- Run /simplify against the diff or changed files
- 'Evaluate each agent''s finding: Reuse (duplicate logic), Quality (maintainability
  footguns), Efficiency (performance waste)'
- Apply findings that are load-bearing or cheap with high signal; explicitly defer
  cosmetic ones with a named follow-up note
- Commit with findings applied or documented
pitfalls:
- Quality agent suggestions (e.g. heredoc refactor) can be correct but out of scope
  for a targeted bug fix — explicitly defer rather than ignore so the follow-up isn't
  lost
- Efficiency findings can reveal real production-path waste (e.g. 300ms wasted overview
  work) — these are worth applying even mid-session
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 20:39:25.147411+00:00'
updated_at: '2026-06-11 20:39:25.147411+00:00'
---

# simplify-three-agent-before-commit

## description

Run /simplify three-agent review (Reuse / Quality / Efficiency) on a diff before committing to catch actionable issues
