---
id: always-on-skill-via-skill-md
project: borg-collective
domain: architecture
tags:
- skill
- always-on
- CLAUDE.md
- auto-install
preconditions: []
steps:
- Create `skills/<rule-name>/SKILL.md` describing the always-on behavior
- Ensure the skill has no activation trigger (or uses an always-true trigger) so it
  is never opt-in
- Verify the existing skill loop in borg setup sources/installs the new skill directory
- Add a test in the bats suite asserting the skill file is present after `borg setup`
pitfalls:
- If the rule also lives in CLAUDE.md, they can drift; prefer the skill as the single
  source of truth and reference it from CLAUDE.md
- Always-on skills that are too verbose slow down context windows; keep the SKILL.md
  tightly scoped
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.217085+00:00'
updated_at: '2026-06-11 22:41:19.217086+00:00'
---

# always-on-skill-via-skill-md

## description

Encode a persistent behavioral rule as a SKILL.md in `skills/<name>/` and rely on the existing skill-install loop to auto-inject it into every session, rather than embedding the rule only in the top-level CLAUDE.md.

