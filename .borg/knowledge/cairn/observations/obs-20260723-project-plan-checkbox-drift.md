---
id: obs-20260723-project-plan-checkbox-drift
session_date: '2026-07-24'
project: cairn
tool: claude-code
tags:
- project-plan
- documentation-drift
- acceptance-criteria
category: gotcha
files_involved: []
confidence: 0.7
source_model: null
source_session: null
superseded_by: null
created_at: '2026-07-24 03:54:03.159892+00:00'
updated_at: '2026-07-24 03:55:24.084484+00:00'
---

# obs-20260723-project-plan-checkbox-drift

## content

PROJECT_PLAN.md acceptance-criteria checkboxes for PR-A (criteria 1-3 + nothing-breaks) were not ticked after the PR merged. A live-read session confirmed they were met but the document still showed them unchecked, creating a false impression that PR-A work was incomplete.

## resolution

Tick the 4 completed PR-A checkboxes in PROJECT_PLAN.md as a housekeeping step at the start of the next session, before beginning PR-B. Establish a convention: tick acceptance criteria checkboxes at merge time, not during review.
