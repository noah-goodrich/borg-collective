---
id: project-status-audit-before-session
project: borg-collective
domain: project-management
tags:
- project-plan
- status-verification
- session-hygiene
preconditions: []
steps:
- 'Grep the PROJECT_PLAN.md for keywords: ''deferred'', ''queued'', ''blocked'', ''pending'',
  ''TODO''.'
- For each deferral note, identify the specific blocker commit or PR it referenced.
- Check git log to confirm whether that blocker has since shipped.
- If the blocker shipped, update the status note and document what actually shipped
  (tests, features, artifacts).
- Commit the status correction as a standalone commit before beginning substantive
  work.
pitfalls:
- Deferral notes are almost never updated when blockers resolve — assume staleness,
  not accuracy.
- A passing test suite and active feature branches are stronger signals of project
  health than prose status fields.
- Portfolio-level directives (e.g. borg-collective) may lag project-level plans by
  multiple sessions — check both.
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 20:39:25.016243+00:00'
updated_at: '2026-06-11 20:39:25.016243+00:00'
---

# project-status-audit-before-session

## description

Verify actual shipped state against documented status before beginning any work session, especially for projects with historical deferral notes.
