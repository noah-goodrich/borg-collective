---
id: obs-20260418-borg-plan-not-run-in-hub-repo
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- borg-plan
- workflow
- borg-collective
- cross-repo
category: domain_knowledge
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 20:39:25.045952+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260418-borg-plan-not-run-in-hub-repo

## content

borg-collective is the planning/tooling hub, but borg-plan skill sessions should be run inside the target work repos (e.g. wayfinderai-waypoint, wallpaper-kit), not inside borg-collective itself. The portfolio directive explicitly names those repos as the active work locus.

## resolution

When the next borg-plan session begins, cd into the appropriate target repo first. Switch to Opus + Plan Mode per SKILL.md before invoking /borg-plan.
