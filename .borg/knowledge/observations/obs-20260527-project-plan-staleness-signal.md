---
id: obs-20260527-project-plan-staleness-signal
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- PROJECT_PLAN
- documentation-drift
- skill-extension-protocol
category: gotcha
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.446952+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260527-project-plan-staleness-signal

## content

PROJECT_PLAN.md described the Skill Extension Protocol as in-progress work, but the implementation had already shipped (SKILL.md files reference skill-extensions/<hook>.md load points, CLAUDE.md documents the protocol). The plan file was misleading about repo state.

## resolution

Captured in a handoff doc (`2026-05-27-project-plan-stale.md`) flagging it as a Noah decision: either move to `docs/plans/assimilated/` with a completion note or rewrite for the next initiative. Do not silently update PROJECT_PLAN.md mid-session without a human call.
