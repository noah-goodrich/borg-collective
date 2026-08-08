---
id: skill-as-enforcement-mechanism
project: borg-collective
domain: architecture
tags:
- skills
- claude
- enforcement
- always-on
preconditions: []
steps:
- Identify a rule that is currently only in global CLAUDE.md but is being violated
- 'Create `skills/<rule-name>/SKILL.md` with trigger: always (or appropriate always-on
  trigger)'
- 'Write the skill to be self-contained: include the rule, rationale, and examples'
- Verify the existing skill auto-install loop picks it up (check borg setup flow)
- Remove or demote the global CLAUDE.md entry to avoid duplication drift
pitfalls:
- Always-on skills add to every context load; keep them concise to avoid token bloat
- If the skill install loop has a path bug, the skill is silently absent — verify
  with a test project
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 20:39:24.966950+00:00'
updated_at: '2026-06-11 20:39:24.966951+00:00'
---

# skill-as-enforcement-mechanism

## description

Use an always-on SKILL.md to enforce a rule that must survive context-window pressure and sync failures
